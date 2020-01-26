class RegisterTest extends ImpTestCase {
    at = null;

    function setUp() {
        at = AT(null);
    }

    // Deregister all callbacks that might be set during a test
    function _clean(_=null) {
        at.onUnhandled(null);
        at.deregisterAll();
        assertTrue(!at.busy());
        assertEqual(0, at._reg.len());
    }

    function testRegister() {
        _clean();

        return Promise(function(resolve, reject) {
            // Here we will collect what tokens have and haven't been handled
            // by our registered function
            local handled = [];
            local unhandled = [];

            // Define some different tokens to feed in
            local tokens = [
                "a",
                "b",
                "aa",
                "ba",
            ];
            // Specify which tokens should and should not be handled by our
            // registered function
            local shouldHandle = [
                "a",
                "aa",
            ];
            local shouldNotHandle = [
                "b",
                "ba",
            ];

            // Initialise expected arrays to empty, we will add to these, and
            // reset them, as we go
            local expectedHandled = [];
            local expectedUnhandled = [];

            // Define a function to register our handled function
            local register = function() {
                at.register(regexp("^a.*"), function(data) {
                    handled.push(data);
                });
            }.bindenv(this)

            // Define function to check that handled and unhandled data is
            // equal to what's expected, then reset them for further use
            local check = function() {
                assertDeepEqual(expectedHandled, handled);
                assertDeepEqual(expectedUnhandled, unhandled);
                handled = [];
                unhandled = [];
                expectedHandled = [];
                expectedUnhandled = [];
            }.bindenv(this);

            // Set handled to collect unhandled data
            at.onUnhandled(function(err, data) {
                if (err) {
                    info("unhandled error: " + err);
                    return reject(err);
                }
                unhandled.push(data);
            }.bindenv(this));

            // Registered, not busy
            register();
            assertTrue(!at.busy());
            foreach (token in tokens) at.feed(token);
            // Handler should handled some, but not others
            expectedHandled.extend(shouldHandle);
            expectedUnhandled.extend(shouldNotHandle);
            check();

            // Registered, busy waiting
            at.wait(0, function(err, _) {
                if (err) return reject(err);
            });
            assertTrue(at.busy());
            foreach (token in tokens) at.feed(token);
            // Handled should handle some, but the others are dropped while
            // waiting (not passed to the onUnhandled callback)
            expectedHandled.extend(shouldHandle);
            check();

            // Not registered, busy waiting
            at.deregisterAll();
            assertTrue(at.busy());
            foreach (token in tokens) at.feed(token);
            // All tokens should be silently swallowed
            check();

            // Registered, busy receiving
            at.stop(null, null);
            register();
            at.receive(@(data) AT.CB_REPEAT, function(err, data) {
                if (err) {
                    info("receive error: " + err);
                    return reject(err);
                } else if (data != null)
                    return reject("should not have received data: " + data);
            });
            assertTrue(at.busy());
            foreach (token in tokens) at.feed(token);
            // Registered callback should handle some, others will be swallowed
            // by `.receive()`'s onData callback
            expectedHandled.extend(shouldHandle);
            check();

            // Not registered, busy receiving
            at.deregisterAll();
            assertTrue(at.busy());
            foreach (token in tokens) at.feed(token);
            // All tokens passed to onData callback, so none collected
            check();

            // Not busy, not registered (again)
            at.stop(null, null);
            assertTrue(!at.busy());
            foreach (token in tokens) at.feed(token);
            // All tokens should be unhandled
            expectedUnhandled.extend(tokens);
            check();

            // All done!
            resolve();
        }.bindenv(this))
            // Cleanup
            .then(
                _clean.bindenv(this),
                function(err) {
                    _clean();
                    throw err;
                }.bindenv(this)
            );
    }

}
