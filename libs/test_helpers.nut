// Sets up two AT instances, a and b, to talk to eachother asyncly
class TestAT {
    a = null;
    b = null;

    constructor() {
        // a's write function should asyncly pass the data to b
        a = AT(function(data) {
            imp.wakeup(0, function() {
                b.feed(data);
            }.bindenv(this));
        }.bindenv(this), 1)
            // Catch unhandled data
            .onUnhandled(_onUnhandled.bindenv(this));

        // b's write function should asyncly pass the data to a
        b = AT(function(data) {
            imp.wakeup(0, function() {
                a.feed(data);
            }.bindenv(this));
        }.bindenv(this), 1)
            // Catch unhandled data
            .onUnhandled(_onUnhandled.bindenv(this));
    }

    // Just log it
    function _onUnhandled(err, data) {
        if (err) {
            server.error("TestAT unhandled error: " + err);
        } else {
            server.error("TestAT unhandled data: " + data);
        }
    }

}

// Generates a callback that calls resolver or reject, as is appropriate, after
// being called n times
function resolver(resolve, reject, n=1) {
    local finished = 0;
    return function(err, data) {
        if (err)
            reject(err);
        else if (++finished == n);
            resolve(data);
    }
}
