class BusyTest extends ImpTestCase {
    at = null;
    operations = null;
    interruptions = null;

    function setUp() {
        at = AT(null);

        // Define the method names and arguments for some operations that
        // should make the AT instance busy.  The callback will be provided
        // later on
        operations = [
            // e.g. at.receive(null, onDone)
            ["receive", null],
            ["wait", 2],
            ["seq", [@(cb) receive(null, cb)]],
        ];

        // Define some functions that can be used to try to interrupt the AT
        // instance.  These functions should fail while the AT instance is busy
        interruptions = [
            @() at.send(""),
            @() at.receive(),
            @() at.wait(0),
        ];
    }

    // Test a single "op"/operation, as defined in `.setUp()`
    function _testOp(op) {
        return Promise(function(resolve, reject) {

            // Parse out the method and arguments
            local opName = op[0];
            local method = at[opName];
            local args = op.slice(1);
            args.insert(0, at);

            // Define the callback, and add it to the supplied arguments
            local stopId = "stopId";
            local onDone = function(err, data) {
                if (err) reject(opName + " error: " + err);
                else if (data == stopId) resolve();
                else reject("unexpected " + opName + "data: " + data);
            }.bindenv(this);
            args.push(onDone);

            // Start the operation
            method.acall(args);

            assertTrue(at.busy());

            // Try each of the different interruptions
            foreach (int in interruptions) {
                local err = assertThrowsError(int, this);
                assertEqual(AT.ERR_BUSY, err);
            }

            // Stop the operation
            at.stop(null, stopId);
            assertTrue(!at.busy());
        }.bindenv(this));
    }

    // Test each operation in series
    function testBusy() {
        local waterfall = Promise.resolve(null);
        foreach (op in operations) {
            local op = op;
            waterfall = waterfall
                .then(function(_) {
                    return _testOp(op);
                }.bindenv(this));
        }
        return waterfall;
    }

}
