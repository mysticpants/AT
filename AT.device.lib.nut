// MIT License
//
// Copyright 2019 Mystic Pants
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// ---------------------------------------------------------------------------
// This class is a generic helper interface for handling AT commands.  It is
// configured with a `write()` function, which it uses to send data to its AT
// partner, and implements a `.feed()` method, which should be called with
// incoming data from its partner.  The `.receive()` method takes a callback
// which can be used to implement complicated logic for checking and parsing a
// variable number of responses from the AT partner as part of a single
// operation.  The `.expect()` method provides a convenient way to generate
// said callbacks to implement common use cases, such as matching a fixed
// sequence of strings, or a regexp.

class AT {
    static VERSION = "1.0.0";

    // We need a unique constant, that won't "==" with anything else, so use an object
    static CB_REPEAT = {};
    static WAIT_STOP = {};
    static ERR_TIMEOUT = "timed out";
    static ERR_BUSY = "AT busy";
    static ERR_NOT_BUSY = "AT not busy";
    static DFLT_TIMEOUT = 60;

    // Expect flags
    static NO_FLAGS = 0;
    static UNORDERED = 1;
    static IGNORE_NON_MATCHING = 2;
    static ALLOW_REPEATS = 4;
    static COLLECT_ALL = 8;
    static USE_MATCH_RESULT = 16;

    log = null;

    // Accumulator variable, to be used by `_onData()` callbacks (cleared on
    // each `_stop()`)
    acc = null;

    // Callback to handle each new piece of data
    _onData = null;
    // Callback for when the current operation succeeds or fails
    _onDone = null;
    // Callback for writing to data to our AT partner
    _onWrite = null;
    // Callback for passing unhandled errors or data
    _onUnhandled = null;
    // Timeout time
    _toTime = null;
    // Timeout timer
    _toTimer = null;
    // Default timeout time
    _dfltTo = null;
    // Registered data handlers
    _reg = null;
    // Whether we're in debug mode
    _debug=false;
    // Wait timeout timer
    _waitTimer = null;

    constructor(onWrite, dfltTo=null) {
        _onWrite = onWrite;
        _dfltTo = dfltTo == null ? DFLT_TIMEOUT : dfltTo;
        _reg = [];
        log = server.log.bindenv(server);
    }

    // Set a callback for unhandled data or errors
    function onUnhandled(cb) {
        _onUnhandled = cb;
        return this;
    }

    // Feed in a piece of data from our AT command partner (e.g. a line from a modem chip)
    function feed(data) {
        _debug && log("<- " + data);

        // Check for registered URC handlers
        for (local i = _reg.len() - 1; i >= 0; i--) {
            local spec = _reg[i][0];
            local cb = _reg[i][1];
            if (_matched(match(spec, data))) {
                local handled = cb(data);
                if (handled != false) return;
            }
        }

        if (_waitTimer) return;
        // Check for an `onData()` handler
        else if (_onData) {
            local cb = _onData;
            _onData = null;
            local res;
            // Call the data handler and get the result
            try {
                res = cb(data);
            } catch (e) {
                return _stop(e, null);
            }

            // Based on the result type, redefine the new data handler
            if (res == AT.CB_REPEAT) _onData = cb;
            else if (typeof res == "function") _onData = res;
            else _stop(null, res);
        } else _unhandled(null, data);
    }

    // `.send()` and `.receive()`
    function cmd(cmd, t=null, onData=null, onDone=null) {
        send(cmd);
        return receive(t, onData, onDone);
    }

    // Send a string of data
    function send(cmd, force=false) {
        if (!force && _busy()) return;
        if (cmd != null) {
            _write(cmd);
        }
    }

    // Receive some data
    // `onData` is a data-handling callback.  When `onData` indicates the receive
    // is finished, the result of the last call to `onData` is passed to `onDone`,
    // which is called once when the receive is finished (like the traditional
    // callback pattern). `t` is a timeout to be applied across the whole
    // `receive()` operation.
    function receive(t=null, onData=null, onDone=null) {
        if (_busy(onDone)) return;
        if (["integer", "float"].find(typeof t) == null) {
            onDone = onData;
            onData = t;
            t = null;
        }
        if (t == null) t = _dfltTo;
        // Default to accepting one response and passing it to onDone
        if (!onData) onData = @(d) d;
        assert(typeof onData == "function");
        _onData = onData;
        resetTimeout(t);
        if (onDone) _setOnDone(onDone);
        return this;
    }

    // Check if we're busy, i.e. in the middle of a `.receive()` operation
    function busy() {
        return !!(_onData || _onDone || _waitTimer);
    }

    // Register a callback function to run whenever a new piece of data matches
    // an expected pattern
    function register(expected, dedupe=null, onRegData=null) {
        if (typeof dedupe == "function") {
            onRegData = dedupe;
            dedupe = null;
        }
        if (dedupe == null) dedupe = false;
        if (dedupe) deregister(expected, true);
        _reg.push([expected, onRegData]);
        return this;
    }

    // Remove a registered callback function, given the `expected` thing that
    // was used to register it in the first place.  Removes the most recently
    // matching callback, or all callbacks registered to `expected` if
    // `all=true`
    function deregister(expected, all=false) {
        for (local i = _reg.len() - 1; i >= 0; i--) {
            if (_reg[i][0] == expected) {
                _reg.remove(i);
                if (!all) break;
            }
        }
        return this;
    }

    function deregisterAll() {
        _reg = [];
        return this;
    }

    // Set debug mode on (default) or off
    function debug(d=true) {
        _debug = d;
        return this;
    }

    // Set the `onDone()` callback, if not already set with `.receive()`
    function _setOnDone(onDone) {
        if (_onDone) _unhandled("onDone callback already set");
        if (!busy()) _unhandled(ERR_NOT_BUSY);
        _onDone = onDone;
        return this;
    }

    // Reset the timeout timer
    function resetTimeout(t=null) {
        if (t) _toTime = t;
        t = _toTime;
        _cancelTo();
        _toTime = t;
        if (t != null && t >= 0) {
            // server.log("resetting timer: " + t);
            _toTimer = imp.wakeup(t, _onTo.bindenv(this));
        }
        return this;
    }

    // Expects one value, or a sequence of matching values
    function expect(expected, flags=null, n=null) {
        if (typeof expected != "array") expected = [expected];
        if (n == null) n = expected.len() - 1;
        flags = flags || NO_FLAGS;

        if (flags & UNORDERED)
            return _expectAll(expected, flags, n);
        else
            return _expect(expected, flags, n);
    }

    // Expects a sequence of responses in order
    function _expect(expected, flags=null, n=null) {
        return function(data) {
            if (acc == null) {
                // First run, setup accumulator state
                acc = {
                    res = (flags & COLLECT_ALL) ? [] : null,
                    i = 0
                };
            }
            local next = expected[acc.i];
            local m = match(next, data);
            local matchedNext = _matched(m);
            // There is a match if we matched the next one, but also if repeats
            // are allowed and we matched the last one again
            if (!matchedNext && flags & ALLOW_REPEATS && acc.i > 0) {
                local last = expected[acc.i-1];
                m = match(last, data);
            }

            if (_matched(m)) {
                // Figure out what data to "save" to return
                local save = flags & USE_MATCH_RESULT ? m : data;
                // Got a match, store the data for onDone (if required)
                if (flags & COLLECT_ALL) acc.res.push(save);
                else if (acc.i == n) acc.res = save;
                // Only increment our position with `expected` if we matched
                // the next element, (not if we matched the last one again
                // because repetitions are allowed)
                if (matchedNext) acc.i++;
                // Check if we're done
                if (acc.i == expected.len()) return acc.res;
            } else if (!(flags & IGNORE_NON_MATCHING)) {
                // No match, and we are looking for *exclusively* elements from
                // the sequence, so this data is unexpected
                throw format("expected \"%s\" but got \"%s\"", "" + next, data);
            }
            return AT.CB_REPEAT;
        }.bindenv(this);
    }

    // Expect a number of matching elements, in any order.  Can be configured
    // to allow *exclusively* matching elements, and to allow repeats.
    //
    // NB: there are ways that this can fail if misused, e.g. if `expected`
    // contains regexps that aren't specific enough and repetitions are
    // allowed, then we will always see matching data as another match for the
    // same `expected[i]`, and always wait to see a match for the other (also
    // matching) `expected[j]`
    function _expectAll(expected, flags=null, n=null) {
        return function(data) {
            if (acc == null) {
                acc = {
                    // Saved result, to pass on to the done callback
                    res = (flags & COLLECT_ALL) ? [] : null,
                    // Number of expected results still outstanding
                    rem = expected.len(),
                    // Number of each expected result found so far
                    found = array(expected.len(), 0)
                };
            }

            // Index of matching element
            local i = null;
            // Result of `.match()`
            local m = null;

            // Find a matching element
            foreach (j, e in expected) {
                // If repetitions are not allowed, and we've already seen this
                // type of result, then skip it
                if (!(flags & ALLOW_REPEATS) && acc.found[j]) continue;
                m = match(e, data);
                if (_matched(m)) {
                    i = j;
                    break;
                }
            }

            if (i != null) {
                // Got a match

                // Store the result if necessary
                local save = flags & USE_MATCH_RESULT ? m : data;
                if (flags & COLLECT_ALL) acc.res.push(save);
                else if (i == n) acc.res = save;

                // If this is our first find for that element type,
                // decrement the number outstanding
                if (acc.found[i]++ == 0)
                    acc.rem--;
            } else if (!(flags & IGNORE_NON_MATCHING)) {
                throw format("no match for data: \"%s\"", data);
            }

            // Continue, or return the result
            return acc.rem == 0 ? acc.res : AT.CB_REPEAT;
        }.bindenv(this);
    }

    static function expectMatch(expected, str) {
        local m = match(expect, str);
        if (!_matched(m))
                throw format("expected \"%s\" but got \"%s\"", "" + expected, str);
        return m;
    }

    // Run a sequence of commands
    // `cmds` is some iterable of commands, to be documented further in examples
    // `cb` is a callback to run when all commands are done (or an error occured)
    // `_data` is used internally when recursing
    function seq(cmds, cb, _data=null) {
        if (_busy(cb)) return;
        try {
            // Convert whatever we've given to a consistent data type/abstraction:
            // a generator.  This will generate next commands.
            local gen = _toGen(cmds);

            // Get the next thing
            local next = resume gen;
            // If the generator is finished, the last `resume` value (the
            // return value) should always be ignored
            if (gen.getstatus() == "dead") return cb(null, _data);

            // Define a callback for when we complete the next action (if any)
            local tmpCb = function(err=null, data=null) {
                if (err) return cb(err, null);
                seq(gen, cb, data);
            }.bindenv(this);

            if (typeof next == "function") {
                // if the next thing is a function, it must be an async function
                // expecting a callback
                next(tmpCb);
            } else if (next == this) {
                // A `.receive()` operation has started, and we should wait for
                // it to finish
                if (_onDone) {
                    // An operation has been started, supplied with onDone
                    // We'll hook tmpCb into that
                    local onDone = _onDone;
                    _onDone = function(err, data) {
                        try {
                            onDone(err, data);
                            err = null;
                        } catch (e) err = e;
                        tmpCb(err, data);
                    }.bindenv(this);
                } else
                    // An operation has been started, not supplied with onDone
                    // We'll use tmpCb
                    _setOnDone(tmpCb);
            } else
                // We've been given a result (synchronously).  This indicates
                // the end of the sequence.
                // At the end of a generator, we get one more `null`, but we
                // should still use the last yielded value as the "return
                // value", hence the ternary
                return cb(null, next);
        } catch (e) {
            return cb(e, null);
        }
    }

    // Match a string against a specifier
    static function match(spec, str) {
        switch (typeof spec) {
            case "bool":
                // Hard-coded to always match or not match
                return spec;
            case "string":
                return spec == str;
            case "function":
                return spec(str);
            case "array":
                // An array spec should match if any element of the array matches
                foreach (expected in spec) {
                    local m = match(expected, str);
                    if (m) return m;
                }
                return false;
            default:
                // Assume it's a regexp, or some class with a `.match()` method defined
                if ("match" in spec && typeof spec.match == "function") {
                    return spec.match(str);
                }
                throw format("cannot match against %s: %s", typeof spec, ""+spec);
        }
    }

    // Check if a `.match()` result counts as a match
    static function _matched(mr) {
        return mr != null && mr != false;
    }

    // Wait for a little while
    // Just `imp.wakeup()`, but taking a binary callback
    function wait(t, cb=null) {
        if (_busy(cb)) return;
        _debug && log("** waiting");

        _waitTimer = imp.wakeup(t, function() {
            _debug && log("** waiting done");
            _stop(null, WAIT_STOP);
        }.bindenv(this));

        _setOnDone(cb);

        return this;
    }

    // Convert any iterable to a generator
    static function _toGen(iter) {
        switch (typeof iter) {
            case "generator":
                return iter;
            case "function":
                return function() {
                    while (true) {
                        local val = iter();
                        if (val == null) return;
                        yield val;
                    }
                }();
            default:
                return function() {
                    foreach (v in iter) {
                        yield v;
                    }
                }();
        }
    }

    // Stop the currently running `.receive()` operation, passing `err` and
    // `data` to the onDone callback
    function _stop(err, data) {
        assert(typeof data != "function");
        acc = null;
        _cancelTo();
        _cancelWaitTimer();
        _onData = null;

        // Pass err,data to onDone
        local cb = _onDone;
        _onDone = null;
        try {
            if (cb)
                return cb(err, data);
        } catch (e) err = e;

        if (err || data != WAIT_STOP) _unhandled(err, data);
    }

    // Manually stop the currently running `.receive()` operation, from outside
    // of this class.
    function stop(err=null, data=null) {
        // Validate that there is actually something to stop
        if (busy()) _stop(err, data);
        else _unhandled(ERR_NOT_BUSY, null);
    }

    // Assert that we're not already busy
    // If given a callback, will call the callback with an error, and return
    // `true` to indicate "yes, we are busy"
    function _busy(cb=null) {
        if (!busy()) return false;

        // We are busy, do something with the error
        if (cb) cb(ERR_BUSY, null);
        else _unhandled(ERR_BUSY, null);

        return true;
    }

    // Write data to our partner, using the supplied `_onWrite` callback
    function _write(data) {
        _debug && log("-> " + strip(data));
        _onWrite(data);
    }

    // Cancel the timeout timer
    function _cancelTo() {
        if (_toTimer) imp.cancelwakeup(_toTimer);
        _toTime = null;
    }

    function _cancelWaitTimer() {
        if (_waitTimer) imp.cancelwakeup(_waitTimer);
        _waitTimer = null;
    }

    // Function to run on timeout
    function _onTo() {
        _stop(ERR_TIMEOUT, null);
    }

    function _unhandled(err, data=null) {
        if (_onUnhandled) _onUnhandled(err, data);
        else if (err) throw err;
    }
}

// Alias some commonly-used functions
AT.ex <- AT.expect;
AT.f <- format;
AT.w <- AT.wait;
