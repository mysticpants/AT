// Define a specification of the tests we are going to run
local spec = [
    {
        // This group sets the `flags` argument of `.expect()` to `AT.NO_FLAGS`
        "flags": AT.NO_FLAGS,
        // Each of these "tests" represents one call to `.expect()` with some
        // given arguments, the resulting callback may then be called many
        // times, passed "inputs" as defined for each test.  Assertions are
        // made about whether the last call to the callback "returns" a given
        // value, or "throws" an error message.
        //
        // "inputs" are the inputs that the resulting callback will be fed, in
        // sequence
        //
        // "expected" is the `expected` argument to `.expect()` (the argument
        // that defines what to expect)
        //
        // "flags" are set for the whole group, and represent the `flags`
        // argument to `.expect()`, which are used to configure the behaviour
        // of the resulting callback
        //
        // "n", if given, is the `n` argument to `.expect()`, which is an index
        // that indicates which of the bits of data fed in (from "inputs")
        // should be returned from the final call to the generated callback
        //
        // "returns", if given, indicates what value should be returned from
        // the final call to the generated callback, when the last "input" is
        // fed in.  All intermediate return values should be AT.CB_REPEAT
        //
        // "throws", if given, indicates that the last call to the generated
        // callback (when it is fed the last of "inputs"), should throw an
        // error, and that the error thrown should match a given
        // MatchSpecification
        "tests": [
            // .expect(["a"], AT.NO_FLAGS) should return "a" after it is fed
            // "a"
            { "inputs": ["a"], "expected": ["a"], "returns": "a" },
            { "inputs": ["a"], "expected": "a",   "returns": "a" },
            // .expect(regexp("a"), AT.NO_FLAGS) should return "a" after it is fed "a"
            { "inputs": ["a"],           "expected": regexp("a"),                "returns": "a" },
            { "inputs": ["a", "b", "c"], "expected": ["a", "b", "c"],            "returns": "c" },
            { "inputs": ["a", "b", "c"], "expected": ["a", "b", "c"], "n": null, "returns": "c" },
            { "inputs": ["a", "b", "c"], "expected": ["a", "b", "c"], "n": 0,    "returns": "a" },
            // .expect(["a", "b", "c"], AT.NO_FLAGS, 1) should return "b" after
            // is fed "a" and "b" and "c"
            { "inputs": ["a", "b", "c"], "expected": ["a", "b", "c"], "n": 1, "returns": "b" },
            { "inputs": ["a", "b", "c"], "expected": ["a", "b", "c"], "n": 2, "returns": "c" },
            // .expect("abc", AT.NO_FLAGS) should throw an error after it is
            // fed "def", and the error message should mention both of those
            // strings
            { "inputs": ["def"],      "expected": "abc",                     "throws": regexp(@".*abc.*def.*") },
            { "inputs": ["a", "def"], "expected": ["a", "abc"],              "throws": regexp(@".*abc.*def.*") },
            { "inputs": ["a"],        "expected": @(str) str.find("a") == 0, "returns": "a" },
        ],
    },
    {
        "flags": AT.UNORDERED,
        "tests": [
            { "inputs": ["a", "b"], "expected": ["a", "b"],         "returns": "b" },
            { "inputs": ["b", "a"], "expected": ["a", "b"],         "returns": "b" },
            { "inputs": ["a", "b"], "expected": ["a", "b"], "n": 0, "returns": "a" },
            { "inputs": ["b", "a"], "expected": ["a", "b"], "n": 1, "returns": "b" },
            { "inputs": ["a", "a"], "expected": ["a", "b"],         "throws":  regexp(".*no match.*")},
            { "inputs": ["a", "x"], "expected": ["a", "b"],         "throws":  regexp(".*no match.*")},
        ],
    },
    {
        "flags": AT.IGNORE_NON_MATCHING,
        "tests": [
            { "inputs": ["a", "b"],      "expected": ["a", "b"], "returns": "b" },
            { "inputs": ["x", "a", "b"], "expected": ["a", "b"], "returns": "b" },
            { "inputs": ["a", "x", "b"], "expected": ["a", "b"], "returns": "b" },
            { "inputs": ["a", "a", "b"], "expected": ["a", "b"], "returns": "b" },
        ],
    },
    {
        "flags": AT.ALLOW_REPEATS,
        "tests": [
            { "inputs": ["a", "b"],                "expected": ["a", "b"],      "returns": "b" },
            { "inputs": ["a", "a", "b"],           "expected": ["a", "b"],      "returns": "b" },
            { "inputs": ["a", "b", "c"],           "expected": ["a", "b", "c"], "returns": "c" },
            { "inputs": ["a", "a", "b", "c"],      "expected": ["a", "b", "c"], "returns": "c" },
            { "inputs": ["a", "b", "b", "c"],      "expected": ["a", "b", "c"], "returns": "c" },
            { "inputs": ["a", "a", "b", "b", "c"], "expected": ["a", "b", "c"], "returns": "c" },
            { "inputs": ["a", "b", "a"],           "expected": ["a", "b", "c"], "throws":  "expected \"c\" but got \"a\"" },
        ],
    },
    {
        "flags": AT.COLLECT_ALL,
        "tests": [
            { "inputs": ["a"],      "expected": "a",        "returns": ["a"] },
            { "inputs": ["a", "b"], "expected": ["a", "b"], "returns": ["a", "b"] },
        ],
    },
    {
        "flags": AT.UNORDERED | AT.IGNORE_NON_MATCHING,
        "tests": [
            { "inputs": ["a", "b"],        "expected": ["a", "b"],          "returns": "b" },
            { "inputs": ["b", "a"],        "expected": ["a", "b"],          "returns": "b" },
            { "inputs": ["b", "c", "a"],   "expected": ["a", "b"],          "returns": "b" },
            { "inputs": ["ba", "bb", "a"], "expected": ["a", regexp("b.")], "returns": "ba" },
            { "inputs": ["bb", "ba", "a"], "expected": ["a", regexp("b.")], "returns": "bb" },
        ],
    },
    {
        "flags": AT.UNORDERED | AT.ALLOW_REPEATS,
        "tests": [
            { "inputs": ["a", "b"],             "expected": ["a", "b"],        "returns": "b" },
            { "inputs": ["b", "a"],             "expected": ["a", "b"],        "returns": "b" },
            { "inputs": ["a", "a", "b"],        "expected": ["a", "b"],        "returns": "b" },
            { "inputs": ["a", "b", "c"],        "expected": ["a", "b", "c"],   "returns": "c" },
            { "inputs": ["a", "b", "b", "c"],   "expected": ["a", "b", "c"],   "returns": "c" },
            { "inputs": ["a", "b", "a", "c"],   "expected": ["a", "b", "c"],   "returns": "c" },
            { "inputs": ["a", "b", "a", "def"], "expected": ["a", "b", "abc"], "throws":  "no match for data: \"def\"" },
        ],
    },
    {
        "flags": AT.UNORDERED | AT.COLLECT_ALL,
        "tests": [
            { "inputs": ["a", "b"], "expected": ["a", "b"], "returns": ["a", "b"] },
            { "inputs": ["b", "a"], "expected": ["a", "b"], "returns": ["b", "a"] },
            { "inputs": ["x"],      "expected": ["a", "b"], "throws":  true },
        ],
    },
    {
        "flags": AT.ALLOW_REPEATS | AT.COLLECT_ALL,
        "tests": [
            { "inputs": ["a", "b"],      "expected": ["a", "b"], "returns": ["a", "b"]},
            { "inputs": ["b"],           "expected": ["a", "b"], "throws":  true },
            { "inputs": ["a", "a", "b"], "expected": ["a", "b"], "returns": ["a", "a", "b"]},
        ],
    },
    {
        "flags": AT.UNORDERED | AT.ALLOW_REPEATS | AT.COLLECT_ALL,
        "tests": [
            { "inputs": ["a", "b"],             "expected": ["a", "b"],        "returns": ["a", "b"] },
            { "inputs": ["b", "a"],             "expected": ["a", "b"],        "returns": ["b", "a"] },
            { "inputs": ["a", "a", "b"],        "expected": ["a", "b"],        "returns": ["a", "a", "b"] },
            { "inputs": ["a", "b", "c"],        "expected": ["a", "b", "c"],   "returns": ["a", "b", "c"] },
            { "inputs": ["a", "b", "b", "c"],   "expected": ["a", "b", "c"],   "returns": ["a", "b", "b", "c"] },
            { "inputs": ["a", "b", "a", "c"],   "expected": ["a", "b", "c"],   "returns": ["a", "b", "a", "c"] },
            { "inputs": ["a", "b", "a", "def"], "expected": ["a", "b", "abc"], "throws":  "no match for data: \"def\"" },

            // Again, making sure "n" doesn't change anything
            { "inputs": ["a", "b"],             "expected": ["a", "b"],        "n": 0, "returns": ["a", "b"] },
            { "inputs": ["b", "a"],             "expected": ["a", "b"],        "n": 0, "returns": ["b", "a"] },
            { "inputs": ["a", "a", "b"],        "expected": ["a", "b"],        "n": 0, "returns": ["a", "a", "b"] },
            { "inputs": ["a", "b", "c"],        "expected": ["a", "b", "c"],   "n": 0, "returns": ["a", "b", "c"] },
            { "inputs": ["a", "b", "b", "c"],   "expected": ["a", "b", "c"],   "n": 0, "returns": ["a", "b", "b", "c"] },
            { "inputs": ["a", "b", "a", "c"],   "expected": ["a", "b", "c"],   "n": 0, "returns": ["a", "b", "a", "c"] },
            { "inputs": ["a", "b", "a", "def"], "expected": ["a", "b", "abc"], "n": 0, "throws":  "no match for data: \"def\"" },
        ],
    },

    {
        "flags": AT.IGNORE_NON_MATCHING | AT.COLLECT_ALL,
        "tests": [
            { "inputs": ["a", "c", "b"], "expected": ["a", "b"], "returns": ["a", "b"] },
        ],
    },

    {
        "flags": AT.USE_MATCH_RESULT,
        "tests": [
            { "inputs": ["a"],      "expected": @(str) str.find("a") == 0,                        "returns": true },
        ],
    },
    {
        "flags": AT.USE_MATCH_RESULT | AT.COLLECT_ALL,
        "tests": [
            { "inputs": ["a"],      "expected": @(str) str.find("a") == 0,                        "returns": [true] },
            { "inputs": ["a", "b"], "expected": [ @(str) "matched", {match = @(str) "matched"} ], "returns": ["matched", "matched"] },
        ],
    },
];

class ExpectTests extends ImpTestCase {
    at = null;

    function setUp() {
        at = AT(null);
    }

    function testExpect() {
        // Foreach group in the test specification...
        foreach (k, group in spec) {
            // Get the flags to be used for every test in this group
            local flags = group.flags;

            // For each test in the group
            foreach (i, test in group.tests) {

                // Get the remaining arguments
                local expected = test.expected;
                local n = "n" in test ? test.n : null;
                // Call `.expect()` with the given arguments to generate a callback
                // (in context, such a callback would normally be passed to
                // `.receive()` as an onData callback)
                local f = at.expect(expected, flags, n);

                // Keep track of what's been returned and thrown
                local returned = null;
                local threw = null;

                // Feed in each input
                foreach (j, input in test.inputs) {
                    try {
                        // Feed in the input and get the return value
                        returned = f(input);
                        // If this is not the last input, the callback should return AT.CB_REPEAT
                        if (j != test.inputs.len()-1)
                            assertEqual(AT.CB_REPEAT, returned);
                    } catch (e) {
                        // Check if it's expected to throw
                        if ("throws" in test) {
                            // It should only ever throw on the last input
                            assertEqual(test.inputs.len()-1, j);
                            threw = e;
                            break;
                        } else {
                            throw e;
                        }
                    }
                }

                // Reset this accumulator, as would normally be done by `._stop()`
                at.acc = null;

                /* info("returned: " + pformat(returned)); */

                // Check the final output
                if (threw) at.expectMatch(test.throws, threw);
                else if ("throws" in test) throw "should have thrown " + test.throws;
                else if ("returns" in test) assertDeepEqual(test.returns, returned);
                else throw "invalid test spec";
            }
        }
    }
}
