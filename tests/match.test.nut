// For each "test" in the array, we'll match the MatchSpecification "spec"
// against the target string "str", and expect the result of the match to be
// "expect".
local tests = [
    // Boolean MatchSpecifications
    { "spec": true,  "str": "",  "expect": true },
    { "spec": true,  "str": "a", "expect": true },
    { "spec": false, "str": "",  "expect": false },
    { "spec": false, "str": "a", "expect": false },

    // String MatchSpecifications
    { "spec": "a", "str": "a",  "expect": true },
    { "spec": "a", "str": "ab", "expect": false },
    
    // Function MatchSpecifications
    { "spec": @(str) true,  "str": "",  "expect": true },
    { "spec": @(str) true,  "str": "a", "expect": true },
    { "spec": @(str) false, "str": "",  "expect": false },
    { "spec": @(str) false, "str": "a", "expect": false },

    // Array MatchSpecifications
    { "spec": ["a"], "str": "a", "expect": true },
    { "spec": ["a"], "str": "ab", "expect": false },
    { "spec": ["a", "ab"], "str": "ab", "expect": true },

    // Table MatchSpecifications (with .match() method)
    { "spec": { "match": @(str) true, } "str": "",  "expect": true },
    { "spec": { "match": @(str) true, } "str": "a", "expect": true },
    { "spec": { "match": @(str) false,} "str": "",  "expect": false },
    { "spec": { "match": @(str) false,} "str": "a", "expect": false },

    // Regexp MatchSpecifications (with .match() method)
    { "spec": regexp("a"), "str": "a", "expect": true },
    { "spec": regexp("a"), "str": "x", "expect": false },
];

// Some things that can't be used as MatchSpecifications
local badSpecs = [
    // Objects don't work without a `.match()` property/method
    {},
    // Generators can't be used in `.match()`
    function() { yield 1; }(),
];

class MatchTests extends ImpTestCase {
    // Test a bunch of combinations, defined above
    function testMatch() {
        foreach (test in tests) {
            assertDeepEqual(test.expect, AT.match(test.spec, test.str));
        }
    }

    // Test the bad MatchSpecifications
    function testBadMatch() {
        local str = "a";
        foreach (spec in badSpecs) {
            local err = assertThrowsError(@() match(spec, str), AT);
            assertTrue(regexp("^cannot match.*").match(err));
        }
    }
}
