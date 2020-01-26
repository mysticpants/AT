class RequestAndResponse extends ImpTestCase {
    _testAt = null;

    function setUp() {
        // Setup test class, so that we can send and receive between two AT
        // instances, "a" and "b"
        _testAt = TestAT();
    }

    function testReqRes() {
        assertTrue(!_testAt.a.busy());
        assertTrue(!_testAt.b.busy());
        return Promise(function(resolve, reject) {
            _testAt.a.receive(null, function(err, data) {
                if (err) return reject(err);
                if (data != "response") return reject("wrong");
                resolve(null);
            }.bindenv(this));

            _testAt.b.receive(null, function(err, data) {
                if (err) return reject(err);
                if (data != "request") return reject("wrong");
                _testAt.b.send("response");
            }.bindenv(this));

            _testAt.a.send("request", true);
        }.bindenv(this));
    }

    // Send a sequence of data from one to the other
    function testSeq1() {
        assertTrue(!_testAt.a.busy());
        assertTrue(!_testAt.b.busy());
        return Promise(function(resolve, reject) {
            // Expect the sequenc on one end
            _testAt.a.receive(_testAt.a.expect(["1", "2", "3", "4"]), resolver(resolve, reject));
            // Send the sequence from the other
            _testAt.b.send("1");
            _testAt.b.send("2");
            _testAt.b.send("3");
            _testAt.b.send("4");
        }.bindenv(this));
    }

    // Send a sequence of data back and forth between 2 instances,
    // like they're having a conversation
    function testSeq2() {
        assertTrue(!_testAt.a.busy());
        assertTrue(!_testAt.b.busy());

        return Promise(function(resolve, reject) {
            local onDone = resolver(resolve, reject, 2);

            // "a" receives 1, sends 2, receives 3, then sends 4
            _testAt.a.seq(function() {
                yield receive(ex("1"));
                send("2");
                yield receive(ex("3"));
                yield wait(0.1);
                send("4");
            }.bindenv(_testAt.a)(), onDone);

            // "b" sends 1, receives 2, sends 3, then receives 4
            _testAt.b.seq(function() {
                send("1");
                yield receive(ex("2"));
                yield wait(0.1);
                send("3");
                yield receive(ex("4"));
            }.bindenv(_testAt.b)(), onDone);
        }.bindenv(this));
    }

    // Same as testSeq2, but using `.seq()` in a different way
    function testSeq3() {
        assertTrue(!_testAt.a.busy());
        assertTrue(!_testAt.b.busy());

        return Promise(function(resolve, reject) {
            local onDone = resolver(resolve, reject);

            _testAt.a.seq([
                @(cb) receive(ex("1"), cb),
                @(cb) (send("2"), cb()),
                @(cb) receive(ex("3"), cb),
                @(cb) wait(0.1, cb),
                @(cb) (send("4"), cb()),
            ], onDone);

            _testAt.b.seq([
                @(cb) (send("1"), cb()),
                @(cb) receive(ex("2"), cb),
                @(cb) wait(0.1, cb),
                @(cb) (send("3"), cb()),
                @(cb) receive(ex("4"), cb),
            ], onDone);
        }.bindenv(this));
    }

    // Same as before again, back and forth between two instances, this time
    // using `.cmd()`
    function testSeq4() {
        assertTrue(!_testAt.a.busy());
        assertTrue(!_testAt.b.busy());

        return Promise(function(resolve, reject) {
            local onDone = resolver(resolve, reject);

            _testAt.a.seq([
                @(cb) receive(ex("1"), cb),
                @(cb) cmd("2", ex("3"), cb),
                @(cb) wait(0.1, cb),
                @(cb) (send("4"), cb()),
            ], onDone);

            _testAt.b.seq([
                @(cb) cmd("1", ex("2"), cb),
                @(cb) wait(0.1, cb),
                @(cb) cmd("3", ex("4"), cb),
            ], onDone);
        }.bindenv(this));
    }

    // Same as before again, back and forth between two instances, this time
    // using `.cmd()` in a generator
    function testSeq5() {
        assertTrue(!_testAt.a.busy());
        assertTrue(!_testAt.b.busy());

        return Promise(function(resolve, reject) {
            local onDone = resolver(resolve, reject);

            _testAt.a.seq(function() {
                yield receive(ex("1"));
                yield cmd("2", ex("3"));
                yield wait(0.1);
                send("4");
            }.bindenv(_testAt.a)(), onDone);

            _testAt.b.seq(function() {
                yield cmd("1", ex("2"));
                yield wait(0.1);
                yield cmd("3", ex("4"));
            }.bindenv(_testAt.b)(), onDone);
        }.bindenv(this));
    }

    // Same as before again, back and forth between two instances, this time
    // using `.cmd()` in a generator, with onDone callbacks
    function testSeq6() {
        assertTrue(!_testAt.a.busy());
        assertTrue(!_testAt.b.busy());

        return Promise(function(resolve, reject) {
            local onDone = resolver(resolve, reject);
            // onDone for intermediary commands
            local tmpOnDone = function(err, data) {
                if (err) throw err;
            };

            _testAt.a.seq(function() {
                yield receive(ex("1"), tmpOnDone);
                yield cmd("2", ex("3"), tmpOnDone);
                yield wait(0.1, tmpOnDone);
                send("4");
            }.bindenv(_testAt.a)(), onDone);

            _testAt.b.seq(function() {
                yield cmd("1", ex("2"), tmpOnDone);
                yield wait(0.1, tmpOnDone);
                yield cmd("3", ex("4"), tmpOnDone);
            }.bindenv(_testAt.b)(), onDone);
        }.bindenv(this));
    }

}
