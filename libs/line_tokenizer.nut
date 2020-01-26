const TOKENIZER_CHECK_TIME = 0.1;

class LineTokenizer {
    _buf = "";
    _checkTimer = null;
    _onToken = null;

    function onToken(onToken) {
        _onToken = onToken;
        return this;
    }

    function feed(data) {
        if (data.find("\x00") != null) {
            for (local i = 0, l = data.len(); i < l; i++) {
                if (data[i] != '\x00') {
                    _buf += format("%c", data[i]);
                }
            }
        } else {
            _buf += data;
        }
        // server.log("TOKBUF: " + pformat(_buf));
        if (_checkTimer != null) imp.cancelwakeup(_checkTimer);
        _checkTimer = null;
        _checkTimer = imp.wakeup(TOKENIZER_CHECK_TIME, check.bindenv(this));
        return this;
    }

    function check() {
        local line;
        local a = _buf.find("\r");
        if (a != null) {
            line = strip(_buf.slice(0, a));
            _buf = lstrip(_buf.slice(a));
        } else if (_buf.len()) {
            line = strip(_buf);
            _buf = "";
        } else {
            return; // all done
        }

        // Drop empty lines
        if (line.len()) {
            _emit(line);
        }
        return check();
    }

    function _emit(token) {
        _onToken && _onToken(token);
    }
}

