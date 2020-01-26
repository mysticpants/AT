class StopTest extends ImpTestCase {
    at = null;

    function setUp() {
        at = AT(null);
    }

    // We will attempt to collect all incoming message to an AT instances for a
    // fixed period of time, by making use of `.stop()`
    function testCollect() {
        local DURATION = 1.5;
        local TIMEOUT = 3;
        local start = hardware.millis();
        // We will store collected data here
        local collected = [];
        // ... and any unhandled data here
        local unhandled = [];
        // Define some tokens to feed to the AT instance
        local tokens = ["a", "b", "c"];

        return Promise(function(resolve, reject) {
            // Collect unhandled data
            at.onUnhandled(function(err, data) {
                if (err) return reject(err);
                unhandled.push(data);
            });

            // Receive data, for *at most* TIMEOUT seconds
            // we won't actually let the TIMEOUT be reached
            at.receive(TIMEOUT, function(data) {
                // Just collect data
                collected.push(data);
                // Keep the `.receive()` operation going
                return AT.CB_REPEAT;
            }, function(err, data) {
                if (err) return reject(err);
                // Here, the `.receive()` operation is now finished, hopefully
                // because we `.stop()`ed it

                // Check that the duration is close enough to what was expected
                local duration = hardware.millis() - start;
                assertTrue(math.abs(DURATION * 1000 - duration) < 200);

                // Check that we collected all the tokens
                assertEqual(collected, data);
                assertDeepEqual(tokens, data);
                assertDeepEqual([], unhandled);

                // Feed another token, the `.receive()` is over now so it should be unhandled
                at.feed("x");

                assertDeepEqual(tokens, data); // unchanged
                assertDeepEqual(["x"], unhandled); // should have got the "x"
                
                // All done!
                resolve();
            }.bindenv(this));

            // Feed the tokens in
            foreach (token in tokens) at.feed(token);

            // stop the receive operation after a fixed DURATION
            imp.wakeup(DURATION, function() {
                at.stop(null, collected);
            }.bindenv(this));
        }.bindenv(this));
    }

}
