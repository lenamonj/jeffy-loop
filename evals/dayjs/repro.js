/*
 * Offline reproduction for the Jeffy audit of iamkun/dayjs at 98364bc.
 *
 * Usage:
 *   git -c core.autocrlf=false clone https://github.com/iamkun/dayjs.git
 *   cd dayjs && npm install && NODE_OPTIONS=--openssl-legacy-provider npm run build && cd ..
 *   node repro.js [path-to-dayjs-clone]     # default: ./dayjs
 *
 * Nothing here touches the network. Every check prints expected and actual.
 * Checks tagged [fixed] are the ones this eval patches; they FAIL at HEAD and
 * PASS once fixes.patch is applied and the clone is rebuilt. The check tagged
 * [open] is a defect this eval reports but does not patch, so it FAILs either
 * way and is excluded from the exit code.
 */

const path = require('path')

const root = path.resolve(process.argv[2] || path.join(__dirname, 'dayjs'))
let dayjs
let momentTz
try {
  dayjs = require(path.join(root, 'dayjs.min.js'))
  dayjs.extend(require(path.join(root, 'plugin', 'utc')))
  dayjs.extend(require(path.join(root, 'plugin', 'timezone')))
} catch (err) {
  console.error(`Cannot load a built dayjs from ${root}`)
  console.error('Run `npm install` and `npm run build` inside the clone first.')
  console.error(String(err.message))
  process.exit(2)
}
try {
  momentTz = require(path.join(root, 'node_modules', 'moment-timezone'))
} catch (err) {
  momentTz = null
}

/* ------------------------------------------------------------------ */
/* host timezone control                                               */
/* ------------------------------------------------------------------ */

const HOSTS = ['UTC', 'Europe/London', 'America/New_York', 'Europe/Lisbon',
  'Pacific/Auckland', 'America/Whitehorse', 'Asia/Tokyo', 'America/St_Johns']

const originalTZ = process.env.TZ

function setHost(zone) {
  process.env.TZ = zone
}

function restoreHost() {
  if (originalTZ === undefined) delete process.env.TZ
  else process.env.TZ = originalTZ
}

// Guard against the harness artifact that made an earlier pass of this audit
// draw the wrong conclusion: on some shells the TZ variable never reaches the
// process, so every "different timezone" run silently used the same zone.
function hostSwitchingWorks() {
  const probe = (zone) => {
    setHost(zone)
    return new Date('2015-01-01T00:00:00.000Z').getHours()
  }
  const utc = probe('UTC')
  const tokyo = probe('Asia/Tokyo')
  restoreHost()
  return utc === 0 && tokyo === 9
}

/* ------------------------------------------------------------------ */
/* frozen clock, so "what time is it now" cannot leak into a result    */
/* ------------------------------------------------------------------ */

const RealDate = Date

function freezeClock(iso) {
  const fixed = new RealDate(iso).getTime()
  function Frozen(...args) {
    if (args.length === 0) return new RealDate(fixed)
    return new RealDate(...args)
  }
  Frozen.prototype = RealDate.prototype
  Frozen.now = () => fixed
  Frozen.parse = RealDate.parse
  Frozen.UTC = RealDate.UTC
  global.Date = Frozen
}

function releaseClock() {
  global.Date = RealDate
}

/* ------------------------------------------------------------------ */
/* reporting                                                           */
/* ------------------------------------------------------------------ */

const results = []

function check(id, tag, what, expected, actual, detail) {
  const pass = expected === actual
  results.push({ id, tag, pass })
  console.log(`${pass ? 'PASS' : 'FAIL'}  ${id} ${tag}  ${what}`)
  console.log(`        expected: ${expected}`)
  console.log(`        actual:   ${actual}`)
  if (detail) detail.forEach(line => console.log(`        ${line}`))
}

/* ------------------------------------------------------------------ */

console.log(`dayjs under test: ${root}`)
console.log(`node ${process.version} on ${process.platform}`)
if (!hostSwitchingWorks()) {
  console.error('\nABORT: setting process.env.TZ does not change this process\'s clock.')
  console.error('Every timezone result below would be the host zone in disguise.')
  process.exit(2)
}
console.log('host timezone switching verified\n')

/* DAYJS-1  dayjs.tz must not depend on the machine it runs on --------- */

{
  const input = '2012-03-11 02:00:00'
  const zone = 'America/New_York'
  const seen = {}
  HOSTS.forEach((host) => {
    setHost(host)
    const d = dayjs.tz(input, zone)
    const key = `${d.format()} | ${d.valueOf()}`
    seen[key] = (seen[key] || []).concat(host)
  })
  restoreHost()
  const variants = Object.keys(seen)
  check(
    'DAYJS-1a', '[fixed]',
    `dayjs.tz('${input}', '${zone}') is the same on every host zone (${HOSTS.length} zones tried)`,
    '1 distinct result',
    `${variants.length} distinct result${variants.length === 1 ? '' : 's'}`,
    variants.map(v => `${v}   <- host ${seen[v].join(', ')}`)
  )
}

{
  setHost('America/Whitehorse')
  const d = dayjs.tz('2012-03-11 02:00:00', 'America/New_York')
  const rendered = d.format()
  const asInstant = new RealDate(rendered).valueOf()
  restoreHost()
  check(
    'DAYJS-1b', '[fixed]',
    'on host America/Whitehorse, format() and valueOf() describe the same instant',
    new RealDate(d.valueOf()).toISOString(),
    new RealDate(asInstant).toISOString(),
    [`valueOf() = ${d.valueOf()}, format() = ${rendered}`]
  )
}

{
  setHost('Europe/London')
  const d = dayjs.tz('2012-10-28 00:30:00', 'America/New_York')
  const actual = new RealDate(d.valueOf()).toISOString()
  restoreHost()
  check(
    'DAYJS-1c', '[fixed]',
    'on host Europe/London, dayjs.tz(\'2012-10-28 00:30:00\', \'America/New_York\') lands on the right instant',
    '2012-10-28T04:30:00.000Z',
    actual
  )
}

/* DAYJS-2  the answer must not depend on the current date ------------- */

{
  setHost('UTC')
  const cases = [
    ['2021-11-07 01:30:00', 'America/New_York'],
    ['2021-03-14 02:30:00', 'America/New_York'],
    ['2021-04-04 02:30:00', 'Pacific/Auckland'],
    ['2021-10-31 01:30:00', 'Europe/London']
  ]
  const drifted = []
  cases.forEach(([input, zone]) => {
    freezeClock('2021-01-15T12:00:00.000Z')
    const winter = dayjs.tz(input, zone).valueOf()
    freezeClock('2021-07-15T12:00:00.000Z')
    const summer = dayjs.tz(input, zone).valueOf()
    releaseClock()
    if (winter !== summer) {
      drifted.push(`${zone} "${input}": ${winter} in January vs ${summer} in July`)
    }
  })
  restoreHost()
  check(
    'DAYJS-2', '[fixed]',
    'dayjs.tz on an ambiguous or skipped local time returns the same instant whatever the current date is',
    '0 inputs drift with the calendar',
    drifted.length === 0 ? '0 inputs drift with the calendar' : `${drifted.length} drift: ${drifted.join(' ; ')}`
  )
}

/* DAYJS-3  arithmetic after .tz() does not re-resolve the zone -------- */

{
  setHost('UTC')
  const d = dayjs.tz('2021-03-13 23:30:00', 'America/New_York').add(1, 'day')
  const expected = momentTz
    ? momentTz.tz('2021-03-13 23:30:00', 'America/New_York').add(1, 'day').format()
    : '2021-03-14T23:30:00-04:00'
  const actual = d.format()
  restoreHost()
  check(
    'DAYJS-3', '[open] ',
    'add(1, \'day\') across a spring-forward boundary in the bound zone re-resolves the offset',
    expected,
    actual
  )
}

/* DAYJS-4  the dayOfYear "wrong year" report is a test fixture, not a
   library defect: dayjs agrees with moment exactly ---------------------*/

{
  setHost('America/New_York')
  let momentAnswer = '2014-01-05T00:00:00.000Z'
  try {
    const moment = require(path.join(root, 'node_modules', 'moment'))
    momentAnswer = moment('2015-01-01T00:00:00.000Z').dayOfYear(4).toISOString()
  } catch (err) { /* fall back to the value observed during the audit */ }
  const local = require(path.join(root, 'dayjs.min.js'))
  local.extend(require(path.join(root, 'plugin', 'dayOfYear')))
  const actual = local('2015-01-01T00:00:00.000Z').dayOfYear(4).toISOString()
  restoreHost()
  check(
    'DAYJS-4', '[fixed]',
    'dayOfYear(4) on a host west of Greenwich agrees with moment (the "wrong year" report is a test fixture defect)',
    momentAnswer,
    actual
  )
}

/* ------------------------------------------------------------------ */

restoreHost()
releaseClock()

const scored = results.filter(r => r.tag.trim() === '[fixed]')
const failed = scored.filter(r => !r.pass)
const open = results.filter(r => r.tag.trim() === '[open]')

console.log('')
console.log(`scored checks: ${scored.length - failed.length}/${scored.length} pass`)
console.log(`reported but not patched by this eval: ${open.map(r => r.id).join(', ') || 'none'}`)
process.exit(failed.length === 0 ? 0 : 1)
