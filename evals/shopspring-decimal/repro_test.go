// Package decimal_test contains the Jeffy audit reproduction cases for
// shopspring/decimal at HEAD 3090cc487febd78d6016c2859c66308328a40e99.
//
// Usage: drop this file into a clone of github.com/shopspring/decimal and run
//
//	go test -run Jeffy -v .
//
// It is offline and self-contained. Against the UNPATCHED library the two
// TestJeffyD* cases fail; fixes.patch makes them pass. The TestJeffyNotRepro*
// and TestJeffyDocumented* cases pass both before and after, and exist to
// record what was observed and to guard the fix against regressions.
package decimal_test

import (
	"math/big"
	"math/rand"
	"testing"

	"github.com/shopspring/decimal"
)

// ---------------------------------------------------------------------------
// exact-rational reference arithmetic, used as the oracle
// ---------------------------------------------------------------------------

func exactRat(d decimal.Decimal) *big.Rat {
	r := new(big.Rat).SetInt(d.Coefficient())
	e := d.Exponent()
	if e < 0 {
		e = -e
	}
	p := new(big.Rat).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(e)), nil))
	if d.Exponent() >= 0 {
		return r.Mul(r, p)
	}
	return r.Quo(r, p)
}

func scaleRat(v *big.Rat, places int32) *big.Rat {
	a := places
	if a < 0 {
		a = -a
	}
	p := new(big.Rat).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(a)), nil))
	out := new(big.Rat).Set(v)
	if places >= 0 {
		return out.Mul(out, p)
	}
	return out.Quo(out, p)
}

func ratFloorInt(r *big.Rat) *big.Int {
	q, _ := new(big.Int).DivMod(r.Num(), r.Denom(), new(big.Int))
	return q
}

func ratCeilInt(r *big.Rat) *big.Int {
	q, m := new(big.Int).DivMod(r.Num(), r.Denom(), new(big.Int))
	if m.Sign() != 0 {
		q.Add(q, big.NewInt(1))
	}
	return q
}

func ratTruncInt(r *big.Rat) *big.Int {
	return new(big.Int).Quo(r.Num(), r.Denom())
}

func ratAwayInt(r *big.Rat) *big.Int {
	if r.Sign() >= 0 {
		return ratCeilInt(r)
	}
	return ratFloorInt(r)
}

func ratHalfAwayInt(r *big.Rat) *big.Int {
	t := new(big.Rat).Set(r)
	if r.Sign() >= 0 {
		return ratFloorInt(t.Add(t, big.NewRat(1, 2)))
	}
	return ratCeilInt(t.Sub(t, big.NewRat(1, 2)))
}

func ratHalfEvenInt(r *big.Rat) *big.Int {
	fl := ratFloorInt(r)
	frac := new(big.Rat).Sub(r, new(big.Rat).SetInt(fl))
	switch frac.Cmp(big.NewRat(1, 2)) {
	case -1:
		return fl
	case 1:
		return new(big.Int).Add(fl, big.NewInt(1))
	default:
		if fl.Bit(0) == 0 {
			return fl
		}
		return new(big.Int).Add(fl, big.NewInt(1))
	}
}

// wantExact computes mode(d * 10^places) / 10^places exactly.
func wantExact(d decimal.Decimal, places int32, mode func(*big.Rat) *big.Int) *big.Rat {
	return scaleRat(new(big.Rat).SetInt(mode(scaleRat(exactRat(d), places))), -places)
}

type roundFn struct {
	name string
	fn   func(decimal.Decimal, int32) decimal.Decimal
	mode func(*big.Rat) *big.Int
}

// The complete exported places-taking rounding family.
func family() []roundFn {
	return []roundFn{
		{"Round", decimal.Decimal.Round, ratHalfAwayInt},
		{"RoundUp", decimal.Decimal.RoundUp, ratAwayInt},
		{"RoundDown", decimal.Decimal.RoundDown, ratTruncInt},
		{"RoundCeil", decimal.Decimal.RoundCeil, ratCeilInt},
		{"RoundFloor", decimal.Decimal.RoundFloor, ratFloorInt},
		{"RoundBank", decimal.Decimal.RoundBank, ratHalfEvenInt},
	}
}

// ===========================================================================
// D1: the rounding family does not agree on the scale of its result.
//
// Round and RoundBank always return a decimal whose exponent is -places.
// RoundUp, RoundDown, RoundCeil and RoundFloor return the INPUT's exponent
// whenever the requested rounding does not change the value. The numeric
// value is always right; the scale is not. Reported upstream as issue #390,
// open since 2024-12-27 and unfixed at HEAD.
// ===========================================================================

func TestJeffyD1_ScaleContract(t *testing.T) {
	cases := []struct {
		in     string
		places int32
		// exponent every member of the family must return
		wantExp int32
		// String() with TrimTrailingZeros disabled
		wantFixed string
	}{
		{"100.0", 0, 0, "100"},     // issue #390 verbatim
		{"-100.0", 0, 0, "-100"},   // same, negative
		{"10.500", 2, -2, "10.50"}, // money: 3dp ledger amount rounded to cents
		{"10.000", 2, -2, "10.00"},
		{"1.10", 1, -1, "1.1"},
		{"4.615", 3, -3, "4.615"}, // already at the requested scale
	}

	restore := decimal.TrimTrailingZeros
	decimal.TrimTrailingZeros = false
	defer func() { decimal.TrimTrailingZeros = restore }()

	for _, c := range cases {
		d := decimal.RequireFromString(c.in)
		for _, f := range family() {
			got := f.fn(d, c.places)
			if got.Exponent() != c.wantExp {
				t.Errorf("%s(%q, %d): exponent = %d, want %d (Round returns %d)",
					f.name, c.in, c.places, got.Exponent(), c.wantExp,
					d.Round(c.places).Exponent())
			}
			if s := got.String(); s != c.wantFixed {
				t.Errorf("%s(%q, %d).String() with TrimTrailingZeros=false = %q, want %q",
					f.name, c.in, c.places, s, c.wantFixed)
			}
		}
	}
}

// The consequence a payment or ledger system actually sees: two amounts put
// through the same RoundUp(2) call serialise at different scales, so the JSON
// payload and the SQL driver value disagree about the precision of the column.
func TestJeffyD1_SerialisationConsequence(t *testing.T) {
	restore := decimal.TrimTrailingZeros
	decimal.TrimTrailingZeros = false
	defer func() { decimal.TrimTrailingZeros = restore }()

	for _, c := range []struct{ in, want string }{
		{"10.500", "10.50"},
		{"10.501", "10.51"},
	} {
		j, err := decimal.RequireFromString(c.in).RoundUp(2).MarshalJSON()
		if err != nil {
			t.Fatal(err)
		}
		if got := string(j); got != `"`+c.want+`"` {
			t.Errorf("RequireFromString(%q).RoundUp(2) MarshalJSON = %s, want %q", c.in, got, `"`+c.want+`"`)
		}
		v, err := decimal.RequireFromString(c.in).RoundUp(2).Value()
		if err != nil {
			t.Fatal(err)
		}
		if got, _ := v.(string); got != c.want {
			t.Errorf("RequireFromString(%q).RoundUp(2) driver.Value = %q, want %q", c.in, got, c.want)
		}
	}
}

// Whole-family sweep: every member must return exponent -places, for every
// input, exactly as Round already does.
func TestJeffyD1_ScaleContractSweep(t *testing.T) {
	rng := rand.New(rand.NewSource(7))
	violations := map[string]int{}
	const iters = 20000
	for i := 0; i < iters; i++ {
		c := new(big.Int).Rand(rng, big.NewInt(1000000))
		if rng.Intn(2) == 0 {
			c.Neg(c)
		}
		d := decimal.NewFromBigInt(c, int32(rng.Intn(9)-8))
		p := int32(rng.Intn(10) - 2)
		for _, f := range family() {
			if f.fn(d, p).Exponent() != -p {
				violations[f.name]++
			}
		}
	}
	for _, f := range family() {
		if n := violations[f.name]; n != 0 {
			t.Errorf("%s returned exponent != -places in %d of %d random cases", f.name, n, iters)
		}
	}
}

// ===========================================================================
// D2: RoundCash silently follows the global DivisionPrecision.
//
// RoundCash is implemented as d.Mul(k).Round(0).Div(k).Truncate(2). Div uses
// the exported, caller-settable DivisionPrecision. Any caller that sets it
// below 2 gets a silently wrong cash amount from a function whose own doc
// comment promises "5: 5 cent rounding 3.43 => 3.45".
// ===========================================================================

func TestJeffyD2_RoundCashIgnoresDivisionPrecision(t *testing.T) {
	cases := []struct {
		in       string
		interval uint8
		want     string
	}{
		{"3.43", 5, "3.45"}, // doc comment of RoundCash, verbatim
		{"-3.43", 5, "-3.45"},
		{"3.45", 10, "3.5"}, // doc comment: "3.45 => 3.50"
		{"3.41", 25, "3.5"}, // doc comment: "3.41 => 3.50"
		{"3.75", 50, "4"},   // doc comment: "3.75 => 4.00"
		{"3.50", 100, "4"},  // doc comment: "3.50 => 4.00"
		{"0.024", 5, "0"},
	}
	restore := decimal.DivisionPrecision
	defer func() { decimal.DivisionPrecision = restore }()

	for _, dp := range []int{0, 1, 2, 3, 16} {
		decimal.DivisionPrecision = dp
		for _, c := range cases {
			got := decimal.RequireFromString(c.in).RoundCash(c.interval).String()
			if got != c.want {
				t.Errorf("DivisionPrecision=%d: RequireFromString(%q).RoundCash(%d) = %q, want %q",
					dp, c.in, c.interval, got, c.want)
			}
		}
	}
}

// ===========================================================================
// Guard: the fix must not move any value. 240k randomised comparisons of the
// whole family against exact rational arithmetic.
// ===========================================================================

func TestJeffyGuard_ValuesStayExact(t *testing.T) {
	rng := rand.New(rand.NewSource(20260727))
	bad := 0
	for i := 0; i < 40000; i++ {
		coeff := new(big.Int).Rand(rng, new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(1+rng.Intn(25))), nil))
		if rng.Intn(2) == 0 {
			coeff.Neg(coeff)
		}
		d := decimal.NewFromBigInt(coeff, int32(rng.Intn(21)-20))
		p := int32(rng.Intn(25) - 8)
		for _, f := range family() {
			got := f.fn(d, p)
			want := wantExact(d, p, f.mode)
			if exactRat(got).Cmp(want) != 0 {
				bad++
				if bad <= 10 {
					t.Errorf("%s(%s, %d) = %s, exact want %s", f.name, d, p, got, want.FloatString(30))
				}
			}
		}
	}
}

// Guard: every "// output:" example in the rounding doc comments still holds.
func TestJeffyGuard_DocExamples(t *testing.T) {
	cases := []struct{ label, got, want string }{
		{"Round(5.45,1)", decimal.NewFromFloat(5.45).Round(1).String(), "5.5"},
		{"Round(545,-1)", decimal.NewFromFloat(545).Round(-1).String(), "550"},
		{"RoundCeil(545,-2)", decimal.NewFromFloat(545).RoundCeil(-2).String(), "600"},
		{"RoundCeil(500,-2)", decimal.NewFromFloat(500).RoundCeil(-2).String(), "500"},
		{"RoundCeil(1.1001,2)", decimal.NewFromFloat(1.1001).RoundCeil(2).String(), "1.11"},
		{"RoundCeil(-1.454,1)", decimal.NewFromFloat(-1.454).RoundCeil(1).String(), "-1.4"},
		{"RoundFloor(545,-2)", decimal.NewFromFloat(545).RoundFloor(-2).String(), "500"},
		{"RoundFloor(-500,-2)", decimal.NewFromFloat(-500).RoundFloor(-2).String(), "-500"},
		{"RoundFloor(1.1001,2)", decimal.NewFromFloat(1.1001).RoundFloor(2).String(), "1.1"},
		{"RoundFloor(-1.454,1)", decimal.NewFromFloat(-1.454).RoundFloor(1).String(), "-1.5"},
		{"RoundUp(545,-2)", decimal.NewFromFloat(545).RoundUp(-2).String(), "600"},
		{"RoundUp(500,-2)", decimal.NewFromFloat(500).RoundUp(-2).String(), "500"},
		{"RoundUp(1.1001,2)", decimal.NewFromFloat(1.1001).RoundUp(2).String(), "1.11"},
		{"RoundUp(-1.454,1)", decimal.NewFromFloat(-1.454).RoundUp(1).String(), "-1.5"},
		{"RoundDown(545,-2)", decimal.NewFromFloat(545).RoundDown(-2).String(), "500"},
		{"RoundDown(-500,-2)", decimal.NewFromFloat(-500).RoundDown(-2).String(), "-500"},
		{"RoundDown(1.1001,2)", decimal.NewFromFloat(1.1001).RoundDown(2).String(), "1.1"},
		{"RoundDown(-1.454,1)", decimal.NewFromFloat(-1.454).RoundDown(1).String(), "-1.4"},
		{"RoundBank(5.45,1)", decimal.NewFromFloat(5.45).RoundBank(1).String(), "5.4"},
		{"RoundBank(545,-1)", decimal.NewFromFloat(545).RoundBank(-1).String(), "540"},
		{"RoundBank(5.46,1)", decimal.NewFromFloat(5.46).RoundBank(1).String(), "5.5"},
		{"RoundBank(546,-1)", decimal.NewFromFloat(546).RoundBank(-1).String(), "550"},
		{"RoundBank(5.55,1)", decimal.NewFromFloat(5.55).RoundBank(1).String(), "5.6"},
		{"RoundBank(555,-1)", decimal.NewFromFloat(555).RoundBank(-1).String(), "560"},
		{"Truncate(123.456,2)", decimal.RequireFromString("123.456").Truncate(2).String(), "123.45"},
		{"StringFixed(5.45,3)", decimal.NewFromFloat(5.45).StringFixed(3), "5.450"},
		{"StringFixedBank(5.45,3)", decimal.NewFromFloat(5.45).StringFixedBank(3), "5.450"},
	}
	for _, c := range cases {
		if c.got != c.want {
			t.Errorf("doc example %s = %q, doc says %q", c.label, c.got, c.want)
		}
	}
}

// ===========================================================================
// Leads that did NOT reproduce. These assertions pass on the unpatched
// library at HEAD and at the last release v1.4.0; they record the observed
// behaviour so the claim is checkable rather than asserted.
// ===========================================================================

// Issue #385 "calling DivRound on a negative number returns a positive number".
// Not reproduced. Division keeps the sign at every precision tried.
func TestJeffyNotRepro_Issue385_DivRoundSign(t *testing.T) {
	cases := []struct {
		a, b      string
		precision int32
		want      string
	}{
		{"-35", "5", 0, "-7"},
		{"-35", "5", 16, "-7"},
		{"35", "-5", 16, "-7"},
		{"-35", "-5", 16, "7"},
		{"-7", "2", 0, "-4"}, // documented: negative quotient, 5 rounds away from 0
		{"-7", "2", 2, "-3.5"},
		{"7", "-2", 0, "-4"},
		{"-2", "3", 2, "-0.67"},
	}
	for _, c := range cases {
		got := decimal.RequireFromString(c.a).DivRound(decimal.RequireFromString(c.b), c.precision).String()
		if got != c.want {
			t.Errorf("DivRound(%s, %s, %d) = %s, want %s", c.a, c.b, c.precision, got, c.want)
		}
	}
	if got := decimal.NewFromFloat(-35.0).Div(decimal.NewFromFloat(5.0)).String(); got != "-7" {
		t.Errorf("issue #385 verbatim: NewFromFloat(-35).Div(NewFromFloat(5)) = %s, want -7", got)
	}
}

// Issue #375 "RoundUp() and RoundDown() with Negative Numbers".
// Not a defect: RoundUp is documented as "rounds the decimal away from zero"
// and RoundDown as "rounds the decimal towards zero", and both doc comments
// carry the negative example the reporter objects to. RoundCeil / RoundFloor
// provide the towards-+/-infinity semantics the reporter expected.
func TestJeffyNotRepro_Issue375_NegativeDirection(t *testing.T) {
	cases := []struct {
		in                             string
		places                         int32
		up, down, ceil, floor, bankers string
	}{
		{"-1.45", 1, "-1.5", "-1.4", "-1.4", "-1.5", "-1.4"},
		{"-1.454", 1, "-1.5", "-1.4", "-1.4", "-1.5", "-1.5"},
		{"1.45", 1, "1.5", "1.4", "1.5", "1.4", "1.4"},
	}
	for _, c := range cases {
		d := decimal.RequireFromString(c.in)
		for _, g := range []struct{ name, got, want string }{
			{"RoundUp", d.RoundUp(c.places).String(), c.up},
			{"RoundDown", d.RoundDown(c.places).String(), c.down},
			{"RoundCeil", d.RoundCeil(c.places).String(), c.ceil},
			{"RoundFloor", d.RoundFloor(c.places).String(), c.floor},
			{"RoundBank", d.RoundBank(c.places).String(), c.bankers},
		} {
			if g.got != g.want {
				t.Errorf("%s(%q, %d) = %s, want %s", g.name, c.in, c.places, g.got, g.want)
			}
		}
	}
}

// Issue #388 "RoundUp can round a number that shouldn't be rounded".
// Not reproduced at HEAD or at v1.4.0. 3.692 * 1.25 is exactly 4.615 carried
// at exponent -5, and RoundUp(3) leaves it alone as it should.
func TestJeffyNotRepro_Issue388_SpuriousRoundUp(t *testing.T) {
	d := decimal.RequireFromString("3.692").Mul(decimal.RequireFromString("1.25"))
	if got, want := d.Coefficient().String(), "461500"; got != want {
		t.Fatalf("product coefficient = %s, want %s", got, want)
	}
	if got, want := d.Exponent(), int32(-5); got != want {
		t.Fatalf("product exponent = %d, want %d", got, want)
	}
	if got := d.RoundUp(3).String(); got != "4.615" {
		t.Errorf("issue #388: (3.692*1.25).RoundUp(3) = %s, want 4.615", got)
	}
	if got := decimal.RequireFromString("4.615").RoundUp(3).String(); got != "4.615" {
		t.Errorf("issue #388: 4.615.RoundUp(3) = %s, want 4.615", got)
	}
}

// ===========================================================================
// Documented-but-surprising behaviour. Reproduced exactly as reported, but it
// follows the doc comment, so it is recorded here rather than filed as a
// defect. Changing it is the maintainer's call.
// ===========================================================================

// Issues #394 and #380. Pow's doc comment states the result of a negative
// exponent has "maximum precision of PowPrecisionNegativeExponent places
// after decimal point", and that variable defaults to 16. 10**-18 therefore
// underflows the fixed scale and comes back as exactly zero.
func TestJeffyDocumented_PowNegativeExponentUnderflow(t *testing.T) {
	if decimal.PowPrecisionNegativeExponent != 16 {
		t.Fatalf("PowPrecisionNegativeExponent = %d, want the documented default 16", decimal.PowPrecisionNegativeExponent)
	}
	for _, c := range []struct {
		exp  int64
		want string
	}{
		{-16, "0.0000000000000001"},
		{-17, "0"}, // silently zero
		{-18, "0"}, // issue #394 verbatim
	} {
		got := decimal.NewFromInt(10).Pow(decimal.NewFromInt(c.exp)).String()
		if got != c.want {
			t.Errorf("10.Pow(%d) = %s, want %s", c.exp, got, c.want)
		}
	}
	// The documented escape hatches both give the exact value.
	r, err := decimal.NewFromInt(10).PowWithPrecision(decimal.NewFromInt(-18), 20)
	if err != nil || r.String() != "0.000000000000000001" {
		t.Errorf("PowWithPrecision(-18, 20) = %s, %v; want 0.000000000000000001, nil", r, err)
	}
	restore := decimal.PowPrecisionNegativeExponent
	decimal.PowPrecisionNegativeExponent = 18
	defer func() { decimal.PowPrecisionNegativeExponent = restore }()
	if got := decimal.NewFromInt(10).Pow(decimal.NewFromInt(-18)).String(); got != "0.000000000000000001" {
		t.Errorf("with PowPrecisionNegativeExponent=18, 10.Pow(-18) = %s, want 0.000000000000000001", got)
	}
}

// Issue #411. NewFromFloat documents that it keeps only the digits needed for
// a reliable float64 round trip, so an int64-exact float64 above 2^53 is not
// preserved digit for digit. NewFromFloatWithExponent(f, 0) is exact.
func TestJeffyDocumented_NewFromFloatShortestRoundTrip(t *testing.T) {
	const f = float64(5202671607238904832)
	if got, want := decimal.NewFromFloat(f).String(), "5202671607238905000"; got != want {
		t.Errorf("NewFromFloat = %s, want %s", got, want)
	}
	if got, want := decimal.NewFromFloatWithExponent(f, 0).String(), "5202671607238904832"; got != want {
		t.Errorf("NewFromFloatWithExponent(f, 0) = %s, want %s", got, want)
	}
	if got, want := decimal.NewFromInt(int64(f)).String(), "5202671607238904832"; got != want {
		t.Errorf("NewFromInt = %s, want %s", got, want)
	}
}
