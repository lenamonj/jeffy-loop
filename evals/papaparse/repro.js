/*
 * Standalone reproduction of the streaming defects this audit found in
 * mholt/PapaParse at HEAD 4eb7eaf0ef10aa0f4edd4306a4dd91bc4b60d998 (2026-07-03),
 * package version 5.5.3, Node 22.18.0.
 *
 * Offline and self-contained: no network, no fixture files, no temp files.
 * Drop it into a clone of PapaParse and run it from the clone root:
 *
 *     git -c core.autocrlf=false clone https://github.com/mholt/PapaParse.git
 *     cd PapaParse && npm install
 *     node path/to/repro.js               # 8 BUG, 1 OK, exit 1
 *     git apply path/to/fixes.patch
 *     node path/to/repro.js               # 9 OK, exit 0
 *
 * An explicit library path may be given as the first argument.
 *
 * Check 8 passes on both sides. It is a guard, not a defect: it records
 * behaviour that was audited and found correct, and it fails loudly if a fix
 * breaks it.
 */
'use strict';

var path = require('path');
var Readable = require('stream').Readable;

var libArg = process.argv[2] || './papaparse.js';
var libPath = path.resolve(process.cwd(), libArg);

// setTimeout is counted for check 7, so it must be wrapped before the library
// captures a reference to it.
var timerCount = 0;
var countingTimers = false;
var realSetTimeout = global.setTimeout;
global.setTimeout = function() {
	if (countingTimers) timerCount++;
	return realSetTimeout.apply(this, arguments);
};

var Papa = require(libPath);

// Two CJK ideographs, 3 UTF-8 bytes each. Built from code points so this file
// stays pure ASCII.
var CJK = String.fromCharCode(0x4e2d, 0x6587);

var failures = 0;
function check(name, ok, detail) {
	if (!ok) failures++;
	console.log((ok ? 'OK  ' : 'BUG ') + name + (detail ? '\n       ' + detail : ''));
}

// A readable stream that delivers exactly the buffers it is given, so chunk
// boundaries are fixed rather than left to the file system.
function chunkStream(chunks) {
	var i = 0;
	return new Readable({
		read: function() {
			this.push(i < chunks.length ? chunks[i++] : null);
		}
	});
}

var checks = [];

// ---------------------------------------------------------------------------
// 1. A chunk boundary inside a multi-byte character must not corrupt the field.
//    ReadableStreamStreamer decoded every Buffer on its own, so the two halves
//    of a split UTF-8 sequence each became U+FFFD.
// ---------------------------------------------------------------------------
checks.push(function(next) {
	var text = 'a,b\n1,' + CJK + '\n2,x\n';
	var bytes = Buffer.from(text, 'utf8');
	var split = bytes.indexOf(0xe4) + 1;          // one byte into the first ideograph
	var rows = [];
	Papa.parse(chunkStream([bytes.slice(0, split), bytes.slice(split)]), {
		step: function(res) { rows.push(res.data); },
		complete: function() {
			var got = rows[1] ? rows[1][1] : '(no row)';
			check('multi-byte character split across a chunk boundary survives',
				got === CJK,
				'expected ' + JSON.stringify(CJK) + ', got ' + JSON.stringify(got));
			next();
		}
	});
});

// ---------------------------------------------------------------------------
// 2. The line-ending guess is cached for the whole file. Taking it from a first
//    chunk that holds no complete line put a stray CR on every last field of a
//    CRLF file, with no error and the right row count.
// ---------------------------------------------------------------------------
checks.push(function(next) {
	var cols = [];
	for (var i = 0; i < 40; i++) cols.push('column_name_number_' + i + '_padded_to_be_long');
	var lines = [cols.join(',')];
	for (var r = 0; r < 20; r++) {
		var cells = [];
		for (var c = 0; c < 40; c++) cells.push('v' + r + '_' + c);
		lines.push(cells.join(','));
	}
	var csv = lines.join('\r\n') + '\r\n';        // first row is 1589 chars, chunk is 1024
	var rows = [];
	Papa.parse(csv, {
		header: true,
		chunkSize: 1024,
		step: function(res) { rows.push(res.data); },
		complete: function() {
			var keys = rows.length ? Object.keys(rows[0]) : [];
			var lastKey = keys[keys.length - 1];
			var lastVal = rows.length ? rows[0][lastKey] : undefined;
			check('line-ending guess is not taken from a truncated first chunk',
				lastKey === 'column_name_number_39_padded_to_be_long' && lastVal === 'v0_39',
				'last header key ' + JSON.stringify(lastKey) + ', last value ' + JSON.stringify(lastVal));
			next();
		}
	});
});

// ---------------------------------------------------------------------------
// 3. header:true with pause()/resume() re-ran header de-duplication over data
//    rows, rewriting duplicate values in place. (upstream issue #998)
// ---------------------------------------------------------------------------
checks.push(function(next) {
	var csv = 'c1,c2,c3\n"foo, bar","foo, bar",v1\n"foo, bar","foo, bar",v2\n"foo, bar","foo, bar",v3\n';
	var rows = [];
	Papa.parse(chunkStream([Buffer.from(csv, 'utf8')]), {
		header: true,
		step: function(res, parser) { parser.pause(); rows.push(res.data); parser.resume(); },
		complete: function() {
			var clean = rows.every(function(r) { return r.c1 === 'foo, bar' && r.c2 === 'foo, bar'; });
			check('header de-duplication does not rewrite data rows after resume (#998)',
				rows.length === 3 && clean,
				'c2 values: ' + JSON.stringify(rows.map(function(r) { return r.c2; })));
			next();
		}
	});
});

// ---------------------------------------------------------------------------
// 4. Same root cause, the shape upstream issue #985 reports: empty trailing
//    fields came back as "_1", "_2" and so on, because empty strings look like
//    duplicate headers to the de-duplicator.
// ---------------------------------------------------------------------------
checks.push(function(next) {
	var csv = 'a,b,c,d\n1,x,,\n2,y,,\n3,z,,\n';
	var rows = [];
	Papa.parse(chunkStream([Buffer.from(csv, 'utf8')]), {
		header: true,
		step: function(res, parser) { parser.pause(); rows.push(res.data); parser.resume(); },
		complete: function() {
			var clean = rows.every(function(r) { return r.c === '' && r.d === ''; });
			check('empty trailing fields stay empty after resume (#985)',
				rows.length === 3 && clean,
				'trailing pairs: ' + JSON.stringify(rows.map(function(r) { return [r.c, r.d]; })));
			next();
		}
	});
});

// ---------------------------------------------------------------------------
// 5. meta.cursor is the documented progress offset. Across pause()/resume() it
//    restarted from the unconsumed remainder, so it went backwards and never
//    reached the end of the input. This is the "loses its place" half of #985.
// ---------------------------------------------------------------------------
checks.push(function(next) {
	var csv = 'a,b,c\n';
	for (var i = 0; i < 200; i++) csv += i + ',value' + i + ',x\n';
	var cursors = [];
	Papa.parse(chunkStream([Buffer.from(csv, 'utf8')]), {
		step: function(res, parser) { parser.pause(); cursors.push(res.meta.cursor); parser.resume(); },
		complete: function() {
			var monotonic = cursors.every(function(c, i) { return i === 0 || c > cursors[i - 1]; });
			var reachedEnd = cursors[cursors.length - 1] === csv.length;
			check('meta.cursor stays absolute across pause/resume (#985)',
				monotonic && reachedEnd,
				'last cursor ' + cursors[cursors.length - 1] + ' of ' + csv.length + ', monotonic=' + monotonic);
			next();
		}
	});
});

// ---------------------------------------------------------------------------
// 6. pause() exists so a caller can stop while it does slow work. It applied no
//    backpressure to a Node stream at all: the source kept running and the rest
//    of the input piled up in an in-memory queue.
// ---------------------------------------------------------------------------
checks.push(function(next) {
	var ROW = '0123456789,abcdefghijklmnopqrstuvwxyz,ABCDEFGHIJKLMNOPQRSTUVWXYZ\n';
	var BLOCK = Buffer.from(ROW.repeat(1000));    // 64 KB per push
	var TARGET = 32 * 1024 * 1024;
	var pushed = 0;
	var src = new Readable({
		read: function() {
			if (pushed >= TARGET) { this.push(null); return; }
			pushed += BLOCK.length;
			this.push(BLOCK);
		}
	});
	var pausedAtBytes = null;
	Papa.parse(src, {
		step: function(res, parser) {
			if (pausedAtBytes !== null) return;
			pausedAtBytes = pushed;
			parser.pause();
			realSetTimeout(function() {
				var extra = pushed - pausedAtBytes;
				check('pause() throttles the source stream',
					extra < 1024 * 1024,
					'source pushed ' + (extra / 1048576).toFixed(1) + ' MB more while the parser was paused, ' +
					((pushed / TARGET) * 100).toFixed(0) + '% of a 32 MB input buffered');
				parser.abort();
				next();
			}, 400);
		},
		complete: function() {}
	});
});

// ---------------------------------------------------------------------------
// 7. resume() called from inside a step callback could not re-enter the parser,
//    so it polled for the halt with setTimeout(resume, 3): one timer per row.
//    That is what makes the project's own regression test for bug #636 exceed
//    its 30 second budget on a platform with a coarse timer.
// ---------------------------------------------------------------------------
checks.push(function(next) {
	var ROWS = 2000;
	var csv = 'a,b,c\n';
	for (var i = 0; i < ROWS; i++) csv += i + ',value' + i + ',x\n';
	var stepped = 0;
	timerCount = 0;
	countingTimers = true;
	var started = Date.now();
	Papa.parse(chunkStream([Buffer.from(csv, 'utf8')]), {
		step: function(res, parser) { stepped++; parser.pause(); parser.resume(); },
		complete: function() {
			countingTimers = false;
			var ms = Date.now() - started;
			check('resume() from a step callback costs no timers',
				timerCount === 0 && stepped === ROWS + 1,
				stepped + ' rows cost ' + timerCount + ' setTimeout calls and ' + ms + ' ms');
			next();
		}
	});
});

// ---------------------------------------------------------------------------
// 8. GUARD, correct at HEAD and it must stay correct: a chunk boundary anywhere
//    inside a quoted field, across an escaped quote, an embedded delimiter or an
//    embedded newline, is handled exactly once the guessers are pinned.
// ---------------------------------------------------------------------------
checks.push(function(next) {
	var csv = 'a,b,c\r\n1,"x, y",z\r\n2,"line1\r\nline2",w\r\n3,"end""quote",q\r\n';
	var base = JSON.stringify(Papa.parse(csv, {newline: '\r\n', delimiter: ','}).data);
	var sizes = [];
	for (var i = 1; i <= csv.length; i++) sizes.push(i);
	var bad = [];
	(function nextSize() {
		if (!sizes.length) {
			check('quoted fields are exact at every chunk boundary',
				bad.length === 0,
				bad.length + ' of ' + csv.length + ' chunk sizes disagreed with a whole-input parse');
			return next();
		}
		var size = sizes.shift();
		var rows = [];
		Papa.parse(csv, {
			newline: '\r\n', delimiter: ',', chunkSize: size,
			step: function(res) { rows.push(res.data); },
			complete: function() {
				if (JSON.stringify(rows) !== base) bad.push(size);
				setImmediate(nextSize);
			}
		});
	})();
});

// ---------------------------------------------------------------------------
// 9. A stream error with no error callback configured was dropped on the floor:
//    the parse stopped with no rows, no complete callback and no diagnostic.
// ---------------------------------------------------------------------------
checks.push(function(next) {
	var src = new Readable({read: function() {}});
	var surfaced = false;
	var onUncaught = function() { surfaced = true; };
	process.once('uncaughtException', onUncaught);
	var completed = false;
	Papa.parse(src, {
		step: function() {},
		complete: function() { completed = true; }
	});
	// An 'error' listener runs synchronously inside emit, so a library that
	// refuses to swallow the error either throws back here or, when the emit
	// comes from Node's own stream machinery, surfaces as an uncaughtException.
	try { src.emit('error', new Error('stream failed')); }
	catch (e) { surfaced = true; }
	realSetTimeout(function() {
		process.removeListener('uncaughtException', onUncaught);
		check('a stream error with no error callback is not swallowed',
			surfaced && !completed,
			'surfaced=' + surfaced + ' complete-called=' + completed);
		next();
	}, 50);
});

// ---------------------------------------------------------------------------

console.log('papaparse under test: ' + libPath);
console.log('');
(function run() {
	var fn = checks.shift();
	if (!fn) {
		console.log('');
		console.log(failures === 0 ? 'all checks OK' : failures + ' check(s) reproduced a defect');
		process.exitCode = failures === 0 ? 0 : 1;
		return;
	}
	fn(function() { setImmediate(run); });
})();
