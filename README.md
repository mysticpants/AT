# AT

This library provides a class to help manage sending AT commands and receiving
responses.  It is independent of any particular method of writing or reading
data to the AT command partner device.  Actually, the class is independent of
"AT commands" as well.  It can be used to manage any kind of synchronous or
asynchronous text-based "conversation" with a partner.

The class is configured with an `onWrite()` function, which it uses to send
data to its AT partner, and implements a `.feed()` method, which should be
passed incoming data from its partner as it becomes available.  The `.receive()`
method takes a special `onData()` callback which can be used to implement
simple or complicated logic for checking and parsing a variable number of
responses from the AT partner as part of a single operation.  The `.expect()`
method provides a convenient way to generate said callbacks to implement common
use cases, such as matching a fixed sequence of strings, or a regexp.  The
`.register()` method can be used to intercept and handle "unsolicited" data
from the partner (URCs).

## Credit

Thanks to [Gordon Williams](https://github.com/gfwilliams), [Pur3
Ltd](http://www.pur3.co.uk/), and [Espruino](http://www.espruino.com) for
inspiring the callback-based API of this library (especially the behaviour of
the `onData()` callback) with their [AT Command
Handler](http://www.espruino.com/AT).

## Class Usage

### Constructor: AT(*onWrite[, dfltTo]*)

This class is instantiated to manage all incoming and outgoing data for an
individual AT command partner, e.g. a single external modem connected to the
Imp over UART could be managed by one instance.  The constructor takes a single
required parameter: a callback for writing data.  This is how the AT lib is
configured to write data to its partner.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *onWrite* | Function | Yes | Callback for writing data to AT command partner |
| *dfltTo* | Float | No | Default timeout for `.receive()` operations for the instance.  Defaults to `AT.DFLT_TIMEOUT`. |

#### Callback: onWrite(*data*)

The callback passed to the constructor is meant to be a function by which the
AT instance can write data to the AT command partner, e.g. for an AT device
connected over UART the callback might be `uart.write`.  Outgoing data from the
AT instance is passed to this callback; incoming data from the AT partner is
passed in to the AT instance via the `.feed()` method (see below).

##### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *data* | String | Yes | Outgoing data to write to the AT command partner |

#### Example

```squirrel
uart <- hardware.uartBCAW;

// Set up the UART
uart.settxfifosize(1024);
uart.setrxfifosize(1024);

// Configure AT lib to write to the UART, with a default timeout for receive
// operations of 90 seconds
at <- AT(uart.write.bindenv(uart), 90);
```

## Instance Methods

### feed(*data*)

This is the method by which the AT instance reads data from its partner AT
device.  Tokens of data (usually lines of text) should be passed in to this
method as they become available.

Note that the tokens that are passed into this method are the "data" that is
passed to `onData()` callbacks.  This decouples the AT class from any
particular source of input.  In some cases, raw data from your source might be
sufficient.  In other cases, you may wish to do some extra preprocessing on
your data before passing it into this class (with this `.feed()` method).  For
example, if reading data from a UART, you might implement some code which
buffers text from the UART, strips out null characters (noise), and splits the
incoming text into (whole) lines.  These lines would then be fed into this
class with `.feed()`, and the tokens availabe to `onData()` would be sanitized
whole lines of text.  By controlling the form of the data that you pass in to
`.feed()` you are controlling the form of the data that you will match against,
parse, or otherwise handle in you `onData()` callback.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *data* | String | Yes | Incoming data from the AT command partner |

#### Example

```squirrel
// Continuing from previous example,
// configure AT lib to read from the UART
uart.configure(QM_UART_BAUD_RATE, 8, PARITY_NONE, 1, 0, function() {
    // For some applications, this might be sufficient.  Others may wish to
    // buffer, filter, split, or otherwise clean this data before passing it into
    // `.feed()`. See below
    at.feed(uart.readstring());
}.bindenv(this));

// Another potential way to handle UART data...
// LineTokenizer is included in `libs`. It is designed to read in UART data then
// strip out null characters, split on carriage returns, strip leading and trailing
// whitespace, and finally output nice and clean lines of text, which in this
// case are the input to the AT instance. LineTokenizer also waits a split second
// before emitting tokens from its buffer, in case single lines of text are split
// and received as multiple UART packets.
local tokenizer = LineTokenizer();

// When the tokizer has a token (a line), feed it to the AT lib
tokenizer.onToken(at.feed.bindenv(at))

// When the UART has data, feed it into the tokenizer.  The UART sends raw data
// to the tokenizer, the tokenizer sends nice tokens to the AT instance
uart.configure(QM_UART_BAUD_RATE, 8, PARITY_NONE, 1, 0, function() {
  tokenizer.feed(uart.readstring());
});
```
---

### cmd(*cmd[, t], onData, onDone*)

This method allows one to send a command to the AT device, wait for a variable
number and format of replies, with a timeout, and execute a standard
error-first callback when the operation is complete.

This is actually just a convenient wrapper around `.send()` and then
`.receive()`, so refer to those methods for documentation of the parameters.

#### Example

```squirrel
function waitForOk(data) {
  if (data == "OK") {
    return null;
  } else return AT.CB_REPEAT;
}

// Execute a power down response, wait for an OK response, timeout after 10
// seconds
at.cmd("AT+PWDWN\r", 10, waitForOk, function(err, data) {
  if (err) {
    return server.error(err);
  }
  // Carry on, the operation was successful
})
```

---

### send(*cmd*)

Used to send data to the AT device.  This method will usually call the
`onWrite()` callback that was configured in the call to the constructor, but
will throw an exception (or pass it to the `onUnhandled()` callback, if set)
instead if the AT instance is busy.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *cmd* | String | Yes | Data to send/write to the AT partner device|

#### Example

```squirrel
// Send a power down command
// This will send the data synchronously and move on, not wait for any response
at.send("AT+PWDWN\r");
```

---

### receive(*[t, onData, onDone]*)

Set a temporary data handler function, wait for a variable number of replies
from the AT partner, and execute a standard error-first callback when the
operation is finished.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *t* | Float | No | Timeout (in seconds) on waiting for the entire operation to complete |
| *onData* | Function | No | Data-handling callback function to be used for the duration of this operation.  See below. |
| *onDone* | Function | No | Error-first callback to execute when the operation is complete.  See below. |

#### Return Value

Returns the AT instance (`this`).

#### Callback: onData(*data*)

This callback should implement the main logic of parsing or otherwise checking
responses that come from the AT command partner.  It will be called as soon as
data received from the partner becomes available.  When called, the function
may indicate any one of the following:

1. The operation completed successfully
2. The operation completed with an error
3. The operation is still in progress, the same `onData()` callback should be
   kept to handle the next available data.
4. The operation is still in progress, but a new `onData()` callback should be
   used to handle the next available data.

The callback will have its environment bound to the AT instance, so if will
have the AT methods available in its scope (if it was not already bound).

If this callback is not provided (i.e. it's value is null), the default
behaviour is to accept any single string as a response, then immediately
complete the `.receive()` operation by passing the received string to `onData()`.

##### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *data* | String | Yes | Data from the AT command partner, as passed into `.feed()` |

##### Return Value

The way the receive operation proceeds is controlled by this callback,
according to the following rules:

1. If the function returns another function, the operation is considered **still
   in progress**, and the newly provided function replaces the existing
   `onData()` callback.
2. If the function returns the constant `AT.CB_REPEAT`, the operation is
   considered **still in progress**, and the existing `onData()` callback is
   retained.
3. If the function returns any other value, the operation is considered
   a **success**.  The return value is then passed as the second
   argument to the `onDone()` callback.
4. If the function raises an exception, the operation is considered complete by
   **failure**.  The exception is passed as the first argument to the `onDone()`
   callback.
5. If the timeout time is reached before the callback has indicated that the
   operation is complete, the operation is considered a **failure**, and
   the error message `AT.ERR_TIMEOUT` is passed as the first argument to the
   `onDone()` callback.

#### Callback: onDone(*err, data*)

A standard asynchronous/Node.js-style error-first callback.  This is called
once when the operation is complete.

##### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *err* | Any | Yes | Any error that occurred during the receive operation |
| *data* | Any | Yes | The result of the operation, if any.  This is normally the value returned by the last invocation of the `onData()` callback |

#### Example

```squirrel
// Imagine that a power down has been triggered on the AT partner, e.g. by pulling
// a power pin high and then low.  We now wish to wait for the partner to send
// "POWERING DOWN", and then "POWER DOWN" to indicate that it has finished
// powering down.  We also wish to time how long the partner takes to power down.

// Record the start time
local start = hardware.millis();

// Start receiving responses
at.receive(function(data) {
  // Fail on "ERROR", this will be caught and passed to `onDone()`
  if (data == "ERROR") throw "failed to power down";
  // Wait for the expected response
  if (data != "POWERING DOWN") return AT.CB_REPEAT;

  // We got the "POWERING DOWN" response, now wait for "POWER DOWN"
  return function(data) {
    // Fail on error, this will be caught and passed to `onDone()`
    if (data == "ERROR") throw "failed while powering down";
    // Wait for the expected response
    else if (data != "POWER DOWN") return AT.CB_REPEAT;

    // We've now received both responses.  The value we return now will be the
    // result of the operation, passed on to our `onDone()` callback below

    // Calculate the duration of the operation
    return hardware.millis() - start;
  }
}, function(err, duration) {
  if (err) server.error("power down failed: " + err);
  else server.log(format("powered down after %d milliseconds", duration));
});
```

---

### stop(*[err, data]*)

Manually stop an in-progress `.receive()` operation.  The currently set
`onData()` callback will be removed, and the `onDone()` callback (if set) will
be called.  This is a way to end a `.receive()` operation that is alternative
to the return value of `onData()`, which obviously can only have an effect each
time there is data to process.  For example, you might wish to stop
`.receive()`ing after a set period of time (but without triggering a timeout
error), or to stop in response to some other stimuli, e.g. a power status pin
going low indicating that the partner has unexpectedly powered down.

`.stop()` throw an exception if the AT instance is not actually in the middle
of an operation.  Should you need to check, you can check for this with
`.busy()`, but beware that naively `.stop()`ing operations can have unintended
consequences (see examples below).  If an `onUnhanled()` callback is set, the
exception will be passed to this callback rather than synchronously thrown.

Note that `.stop()` is not effective in stopping a sequence of commands
controlled by `.seq()`, as it will *only* stop the currently in-progress
`.receive()` operation, and the rest of the sequence will be allowed to
continue.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| err | Any (usually a String or Null) | No | Error to pass to `onDone()` |
| data | Any  | No | Data to pass to `onDone()` |

#### Example

Suppose an AT command will give you multiple lines of data, which you wish to
store in an array.  You don't know what they might look like, or how many there
might be, but you expect them all to arrive within 5 seconds.  You could
collect all responses for 5 seconds, and then manually end the `.receive()`,
like so:

```squirrel
local received = [];

// Execute the send, and initiate the receive operation
at.cmd("AT+SENSORVALUES?\r", function(data) {
  received.push(data);
  return AT.CB_REPEAT;
}, function(err, values) {
  if (err) {
    // Handle the error
    // ....
  }

  server.log(format("got %d sensor value", values.len()));
  // Do something with the values
  // ...
});

// After 5 seconds, end the receive operation, passing the array of received
responses to the onDone callback
imp.wakeup(5, function() {
  at.stop(null, received);
});
```

#### Bad Example

A non-recommended use-case is to attempt to abort any currently running
operation, without knowing what the operation actually is.  For example, if
some part of your code decides it has a really important AT command to execute,
so it does the following:

```squirrel
// Stop whatever command is running now, if there is one
if (at.busy()) at.stop();

// Now the instance isn't busy, so we can run a comand, right?  Probably wrong.
// Don't do this.
at.cmd(/* ... */);
```

...this is bad, because the AT partner might still be about to send us a
response for a previously sent AT command, for which the `.receive()` operation
had not finished.  If this response comes during our next command instead, we
won't be expecting it and that could problems.

---

### busy()

Check if the AT instance is "busy", i.e. in the middle of a `.receive()`
operation.  The instance is unavailable for other `.send()`, or `.receive()`
commands while it is busy.  The instance cannot be `.stop()`ed unless it *is*
already busy.

#### Return Value

A boolean.

#### Example

```squirrel
// Define a function that will check the clock on our AT partner every 60 seconds
// or so, as long as it's not busy executing more important commands for some
// other part of our application
local checkClockIfIdle;
checkClockIfIdle = function() {
  imp.wakeup(60, function() {
    if (at.busy()) return checkClockIfIdle();
    at.cmd("AT+CLOCK\r", expect(regexp(@"^\d+$")), function(err, clock) {
      if (err) server.error("failed to check clock: " + err);
      else server.log(format("Imp time: %d, AT partner clock time: %s", time(), clock));
      checkClockIfIdle();
    });
  });
}

// Start checking
checkClockIfIdle();
```

---

### register(*expected[, dedupe], onRegData*)

Register a callback to run each time a piece of incoming data matches an
expected specification, e.g. when a line starts with a certain prefix string.
This can be used for when the AT partner (e.g. a modem) sends unsolicited
results asynchronously at times we can't predict (e.g. notifications of UDP
that has been sent to our modem from another source).

Registered functions are checked against incoming data in order from last
registered to first registered.  This might seem "backwards", but think of it
like a stack of handlers, rater than a queue.  You can `.register()` temporary,
more specific handlers to override "base" handlers that you may have set up at
the start of your application.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *expected* | MatchSpecification | Yes | A value used to test if incoming data is a match.  See the documentation for `.match()` for more details on this type. |
| *dedupe* | Boolean | No | Whether existing registrations should be de-duplicated.  If true, all existing registrations with the same `expected` MatchSpecification will be removed. |
| *onRegData* | Function | Yes | Callback to run on matching data. |

##### Callback: onRegData(*data*)

Called each time a match is seen.

###### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *data* | string | Yes | The matching data|

###### Return Value

Can return `false` to indicate that the data was not actually relevant (despite
matching).  This will cause the AT instance to continue checking for other
matching registrations, or fall through to passing to the data to an
in-progress `.receive()` operation.

###### Example

```squirrel
function readUdpData(notification) {
  // Read and process UDP data from the AT modem
  // ...
}

// Regexp match for unsolicited UDP notifications, which indicate that there is
// UDP data available to be read from our AT partner
local udpNotificationRe = regexp("^\+UDP: .*$");

// Register our read callback to run whenever we are notified that there is data
// available
at.register(udpNotificationRe, readUdpData);
```

---

### deregister(*expected[, all]*)

Deregister one or more matching registrations registered by `.register()`.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *expected* | MatchSpecification | Yes | As originally passed to `.register()` |
| *all* | Boolean | No | Whether to remove **all** matching registrations.  Default is `false`, which removes only the most recent matching registration. |

#### Example

```squirrel
// Continuing on from `.register()` example...

// We are no longer expecting any incoming UDP data, so deregister the callback
// Note that we must remember the `expected` MatchSpecification that was used
// to register the callback, to use as an ID for deregistering
at.deregister(udpNotificationRe);
```

---

### deregisterAll()

Remove all registered callbacks, i.e. undoes all previous calls to `.register()`.

---

### onUnhandled(*cb*)

Set a callback to be run when there are is any unhandled AT data, or unhandled errors.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *cb* | Function | Yes | A binary callback to run when there is anything unhandled.  Will be called with *either* an error as the first argument, *or* some unhandled data as the second argument. |

#### Example

```squirrel
at <- AT(uart.write.bindenv(uart), 90)
  .onUnhanled(function(err, data) {
    if (err) server.error("unhandled AT error: " + err);
    else server.log("WARNING unhandled AT data: " + data);
  });
```

---

### resetTimeout(*t*)

Reset the timeout on a `.receive()` operation.  This could be used in an `onData()` callback to extend the timeout during a `.receive()` operation.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *t* | Float | No | Time (in seconds, from now) until timeout.  Defaults to the original timeout time set in `.receive()`, but reset to be from the current time. |

#### Example

```squirrel
function waitForOk(data) {
  if (data == "OK") {
    // Got the "OK", all done
    return null;
  } else {
    // Reset the timeout any time we receive any data
    resetTimeout()
    return AT.CB_REPEAT;
  };
}

// Execute a command.  Wait for an OK response, and timeout if 10 seconds
// pass without *any* responses
at.cmd("AT+PWDWN\r", 10, waitForOk, onDone);
```

---

### seq(*cmds, cb*)


Used to run a sequence of asynchronous tasks, similar to Javascript's
[`async.series()`](https://caolan.github.io/async/docs.html#series).  Normally
this will include a number of `.send()` and `.receive()` operations.  An
iterable sequence of asynchronous commands is executed until completion (the
last command completes successfully, or there is an error), then the result is
passed to the callback `cb()`.

Note that if your "sequence" is just a send followed by a receive, you should
use `.cmd()` which does exactly that.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *iter* | Iterable (see `.toGen()`) | Yes | Asynchronous command specification (see below, and see examples) |
| *onDone* | Function | Yes | Callback to execute when sequence is complete.  If successful, the callback will be passed the data returned by the last command in the sequence (as its second argument). |

`cmds` is converted to a generator in order to iterate the commands asynchronously, according to the following rules:

| Type | Behaviour |
| --- | --- |
| Generator | Passes through untouched |
| Function | Called multiple times to generate each new value, until it returns `null`, at which point the generator is exhausted |
| Other (Array, Class, Table) | Iterated according to `foreach (value in cmds) { ... }`|

Why use one type over another?  I have some general recommendations.  You
should use an array (of functions) if executing a short, fixed sequence of
commands.  You should use a generator if your situation is complicated by any
of the following factors:

- The sequence of commands is long, or even infinite - so that loading all
  commands in the sequence into memory at once is undesirable or impossible
- The sequence of commands may need to change while still in progress, e.g. if:
    - The data sent by one command relies on the result of a previous command
    - The sequence may need to branch in different directions (e.g. in response
      to some data received early in the sequence, or some other asynchronous
      source of information)
    - An infinite sequence needs to be aborted early when some condition is met

To read more about generators, see [the Squirrel 3.0 Reference
Manual](http://www.squirrel-lang.org/doc/squirrel3.html#d0e1827) or [the
Electric Imp docs](https://developer.electricimp.com/resources/generators).

At each step, the value yielded by the iterable may be of one of 3 cases:

| Type | Meaning |
| --- | --- |
| Function | This user-supplied function is assumed to be an asynchronous function taking one argument, a binary error/data callback function we'll call `onNext()`.  `onNext()` is passed to the function, and the sequence continues when the user's function calls it.  If the command is the last in the sequence, the `data` value supplied to the callback becomes the "return value" of the sequence, i.e. it is passed to the `onDone()` callback passed to `.seq()`.  |
| `this` | `this` indicates a reference to the AT instance.  Yielding this value to `.seq()` indicates that a `.receive()` (or `.wait()`) operation has been started for the given instance, so that it is now busy, and that `.seq()` should wait for the operation to finish before continuing.  This can be convenient to yield because `this` is the return value of `.receive()`, `.wait()`, and `.cmd()`.  |
| Other | The sequence is complete, and the "return value" of the sequence is set to this yielded value.  |

A step in the sequence may also raise an exception, by `throw`ing or by passing
an error message to a supplied callback, in which case the sequence is aborted
and the error is passed as the first argument to the `onDone()` callback.

The sequence stops when:

- An exception is raised (for example with `throw`, or by passing an passing an error to `onNext()`)
- The sequence of commands `iter` is exhausted

#### Example

```squirrel
local numberRe = regexp("^\d+$");

function checkTime(cb=null) {
  // Execute clock command, wait for "OK" and then time
  return at.cmd("AT+CLOCK?\r", at.expect("OK", numberRe), function(err, time) {
    if (err) return cb(err, null);
    server.log("external clock time: " + time);
    cb(null, time);
  });
}

function checkTemp(cb=null) {
  // Execute check temperature command, wait for "OK" and then temperature
  return at.cmd("AT+TEMP?\r", at.expect("OK", numberRe), function(err, temp) {
    if (err) return cb(err, null);
    server.log("temperature reading: " + temp);
    cb(null, temp)
  });
}

// Define callback to run when a sequence is complete
// `data` will be the result obtained by executing the sequence, i.e. the value
// asyncronously "returned" by the last command in the sequence
function onDone(err, data) {
  if (err) server.error("Error in sequence: " + err);
  else server.log("Sequence completed with result: " + data);
}

// Check time
checkTime(onDone);

// Check time, then temperature
at.seq([
  @(cb) checkTime(cb),
  @(cb) checkTemp(cb),
], onDone);

// Equivalently...
at.seq([
  checkTime,
  checkTemp,
], onDone);

// Check time and temperature twice, doing something else in between
at.seq([
  checkTime,
  checkTemp,
  function(cb) {
    try {
      // Do something...
      cb(null, data);
    }
    catch (err) {
      cb(err, null);
    }
  },
  checkTime,
  checkTemp,
], onDone);

// Check time and temperature twice, waiting 10 seconds in between
at.seq([
  checkTime,
  checkTemp,
  @(cb) wait(10, cb),
  checkTime,
  checkTemp,
], onDone);

// Equivalently...
// In this example we pass in a generator, by defining a generator function and
// calling it to get an instance of the generator.  There is little advantage to
// using a generator over an array for this example.
at.seq(function() {
  // no callback passed in (and the returned value is non-null and
  // non-function)`, thus `.seq()` will wait until the AT instance stops being
  // busy before continuing
  yield checkTime();
  yield checkTemp();
  // yielding an async function still works here, but check the next example to
  // see a more convenient way of using `.wait()` in this context
  yield @(cb) wait(10, cb);
  yield checkTime();
  yield checkTemp();
}(), onDone);

// Check time and temperature every 10 seconds forever (or until an error occurs)
// Here the generator shows its strength: we can use it to represent an
// infinite sequence, without loading an infinite number of functions (in an
// array) into memory
at.seq(function() {
  while (true) {
    yield checkTime();
    yield checkTemp();
    // `.wait()` is a kind of `.receive()` operation too, so we can `yield` to `.seq()`
    // without a callback just like we do when kicking off `.receive()` operations
    yield wait(10);
  }
}(), onDone);

// Equivallently, using a function instead of a generator
local cmds = [checkTime, checkTemp, @(cb) wait(10, cb)];
local i = 0;
// The provided function is called at the end of each command to get the next
// command to run
at.seq(function() {
  // Get the next command
  local cmd = cmds[i];
  // Increment the index, wrapping around the end of the array
  i = (i + 1) % cmds.len();
  return cmd;
}, onDone);

// Check time continuously forever (or until an error occurs), as fast as possible.
// The `checkTime()` function can be used directly.  It is called to inititate
// each command in the sequence (in this case, always "check the time").  Since it
// returns a non-null, non-function value, `.seq()` will wait until the command it
// initiated completes before the calling the function again to initiate the next
// command.
at.seq(checkTime, onDone);
```

---

### expect(expected[, n, ex])

A factory method for generating `onData()` callbacks to handle common use
cases.  Calling this method, with one or more arguments for configuration, will
return a callback that can be used as an `onData()` callback.  The callback
will expect one or more matching responses in a given order, either exclusively
(by default) or with potentially other responses in between.  Completes the
`.receive()` operation when matches have been seen for all expected responses
in the correct order, or raises an exception.

Aliased to `.ex()`.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *expected* | MatchSpecification or [MatchSpecification] | Yes | Specification(s) of expected response(s). Note that an array value will be assumed to be an array of MatchSpecifications each representing a single expected response, not an array-type MatchSpecification intended to match a single response with multiple potential values.  If you wish to match a single response with an array-type MatchSpecification, simply wrap it in another array to indicate that you are expecting a sequence of length 1 - and the response should be matched against the inner array MatchSpecification. See the nested array examples below. |
| *flags* | Integer (bitfield) | No | Effects the behaviour of the resulting callback function in various ways, see below. |
| *n* | Integer | No | Index into `expected` array of response that should be passed on as data to the `onDone()` callback.  E.g. if a `.receive()` operation should expect 3 responses, and only the second response contains meaningful data, then use `n=1`.  Defaults to the last item, `n=expect.len()-1`|

##### Flags

The `flags` argument to `.expect()` is a bitfield, which can be used to set
various flags that effect the behaviour of the resulting callback function.
All flags are off by default, and can be combined with bitwise OR, e.g. to set
the flags `UNORDERED` and `COLLECT_ALL`, pass a `flags` value of `UNORDERED |
COLLECT_ALL`.  For a detailed explanation and examples of each flag, see the
"Class Properties" section of this README.  For a brief overview, see this
table, and for some examples of common flag combinations, see the examples
below.

| Flag | Value | Description |
| --- | --- | --- |
| NO\_FLAGS | 0 | Does not set any flag, so has no effect.  Can be used in place of `0` to explicitly not set any flags. |
| UNORDERED | 1 | Allow matches to come in any order. |
| IGNORE\_NON\_MATCHING | 2 | Silently ignore non-matching data, rather than treating them as errors. |
| ALLOW\_REPEATS | 4 | Allow repeatedly matching each `expected` element. |
| COLLECT\_ALL | 8 | Collect all matched data in an array to pass on to `onData()` at the end, rather than just the `n`-th. |
| USE\_MATCH\_RESULT | 16 | When a match is found, save the result of `.match()` to pass on to `onData()`, rather than the raw data that was matched. |

#### Example

```squirrel
// Expect an "OK" response
at.cmd("AT+PWDWN\r", 10, at.expect("OK"), onDone);

// Expect an "OK" response, then a "POWER DOWN" response
at.cmd("AT+PWDWN\r", 10, at.expect(["OK", "POWER DOWN"]), onDone);

// Expect an "OK" response, then either "POWER DOWN" or "POWER DOWN"
at.cmd("AT+PWDWN\r", 10, at.expect(["OK", ["POWER DOWN", "POWERED DOWN"]]), onDone);

// Expect either "POWER DOWN" or "POWER DOWN"
// NB: without the second layer of array, this would expect "POWER DOWN", *and
// then* "POWERED DOWN"
at.cmd("AT+PWDWN\r", 10, at.expect([["POWER DOWN", "POWERED DOWN"]]), onDone);

// Expect a "POWER DOWN" response eventually
at.cmd("AT+PWDWN\r", 10, at.expect("POWER DOWN", AT.IGNORE_NON_MATCHING), onDone);

// Expect an OK response, followed by some data, followed by another OK
// The data response (index 1) should be passed to `onDone()`
at.cmd("AT+VERSION\r", 10, at.expect(["OK", regexp("^data: .*$"), "OK"], AT.NO_FLAGS, 1), onDone);

// Expect an "OK" and a "POWER DOWN", in either order
at.cmd("AT+PWDWN\r", 10, at.expect(["OK", "POWER DOWN"], AT.UNORDERED), onDone);

// Expect an "OK" response, and a "POWER DOWN" response, in either order, and
// possibly with other non-matching responses in-between
at.cmd("AT+PWDWN\r", 10, at.expect(["OK", "POWER DOWN"], AT.UNORDERED | AT.IGNORE_NON_MATCHING), onDone);

// Expect at least one "OK", and at least one "POWER DOWN", and no other
// responses.  Calls `onDone()` as soon as both responses have been seen once or
// more.
at.cmd("AT+PWDWN\r", 10, at.expect(["OK", "POWER DOWN"], AT.UNORDERED | AT.ALLOW_REPEATS), onDone);

// Expect some numbers, followed by an "OK"
// Collect all these responses into an array to pass to `onDone()`
at.cmd("AT+SENSORDATA?\r", 10, at.expect([regexp(@"^\d+$"), "OK"], AT.ALLOW_REPEATS | AT.COLLECT_ALL), onDone);
```

---

### debug([enable])

Enable or disable debugging for the AT instance.  This will enable debug logs
of incoming and outgoing data.  Deriving classes may choose to implement
further debug functionality.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *enable* | Boolean | No | Whether to enable debugging, or to disable it.  Defaults to `true`, meaning to enable debugging.  |

#### Example

```squirrel
// Enable debugging
at.debug();

// Do some troublesome operations
// ...

// Disable debugging again
at.debug(false);
```

## Class Methods

### match(*spec, str*)

Executes a match on a target string according to some specification.  That
specification is defined as a "MatchSpecification", documented below.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *spec* | MatchSpecification | Yes | Specification of match.  See below. |
| *str* | String | Yes | String to match against. |

#### MatchSpecification

A match specification works in different ways depending on its type.

| Type | Behaviour |
| --- | --- |
| Boolean | Always matches (if true) or doesn't match (if false), ignoring the contents of the string |
| String | Matches if the strings are identical |
| Regexp | Matches if the regexp matches the string according to the `regexp.match()` method |
| Function | Is called, with the string as its only argument.  The return value (a boolean) indicates whether there was a match |
| [MatchSpecification] | Matches if the string matches any of the given array of MatchSpecifications |
| Class, Instance, or Table | Must implement a `.match()` method, which is called with the string as its only argument, similar to using a function type MatchSpecification.  You can pass in an instance of an object that implements custom matching logic (e.g. an instance of a custom Regexp class, or a custom parsing class), as long as you have implemented this `.match()` method. |

##### `regexp.match()`

If using regexps, it is important to know that `regexp.match()` checks if the
regexp matches against *the entire target string*.  This means that
`regexp("OK")` will only match the exact string `"OK"`, and not any other
string that contains "OK".  If you want the other behaviour, you could try
making use of `regexp.search()`, perhaps by wrapping the regexp in a function
or custom class, e.g.:

```squirrel
local re = regexp("OK");

// Make a function-type MatchSpecification, making use of regexp.search()
local matchOk = function(str) {
  return re.search(str) != null;
}

// Compare the pair...

at.match(re, "OK"); // true
at.match(matchOk, "OK"); // true

at.match(re, "--- OK ---"); // false
at.match(matchOk, "--- OK ---"); // true
```

#### Return Value

Can return any kind of value, depending on the MatchSpecification.  For
example, if the MatchSpecification is a simple boolean, string, or regexp, the
return value will be a boolean, but if the MatchSpecification is a function
then the return value will be the result of executing the function on the
target string.

A return value of `null` or `false` is taken to mean "does not match", and any
other value is taken to mean "does match" (notable examples include `""` and
`0`).

#### Example

```squirrel
// Always true
at.match(true, s);

// Always false
at.match(false, s);

// Matches "OK" exactly
at.match("OK", s);

// Matches if string contains "OK"
at.match(regexp(@"^.*OK.*$"), s);

// Matches "OK" case-insentively
at.match(function (str) {
  return str.toupper() == "OK";
}, s);

// Equivalently...
at.match(@(str) str.toupper() == "OK", s);

// Implement a custom Regexp class with a better `._tostring()` method for easier debugging
class RE {
    _re = null;
    _str = null;

    constructor(str) {
        _str = str;
        _re = ::regexp(str);
    }

    // Debuggable _tostring() method
    function _tostring() {
        return "/" + _str + "/";
    }

    // Defer to the interal regexp object for any other properties or methods
    function _get(idx) {
        local v = _re[idx]
        return typeof v == "function" ? v.bindenv(_re) : v;
    }

}

// Matches if string contains "OK"
at.match(RE(@"^.*OK.*$"), s);

// Passes if string contains "OK", otherwise throws an error.  The error
// message will contain a stringified version of the MatchSpecification, which is
// now more readable with our custom RE class than it would have been for a raw
// regexp object
at.expectMatch(RE(@"^.*OK.*$"), s);
```

---

### expectMatch(*expected, str*)

Utility method.  Throws a nice error message if string `str` does not match
MatchSpecification `expected`, according to the behaviour of `.match()`.  Can
be used inside of `onData()` callbacks to make assertions that throw
meaningful error messages without extra boilerplate.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *expected* | MatchSpecification | Yes | Specification of match.  See documentation of this type under that for `.match()`. |
| *str* | String | Yes | String to match against. |

#### Returns

If no error is thrown from the assertion, returns the result of
`.match(expected, str)`.  This is guaranteed to not be `null` or `false`, but
could be any other value (including `0`) depending on the `expected`
MatchSpecification.

#### Example

```squirrel
at.cmd("AT+CLOCK\r", function(data) {
  // Make sure that the format of the data matches what we expect
  at.expectMatch(regexp("^\d+$"), data);
  // Convert data to integer before passing to `onDone`
  return data.tointeger();
}, function(err, clockTime) {
  // ... handle the data
});
```

---

### wait(*t, onDone*)

Like `imp.wakeup()` for your AT instance.  Waiting is treated like a receiving, which means:

- The AT instance is "busy" while waiting
- You can stop your `.wait()` early with `.stop()`
- `.seq()` can handle wait operations automatically, just like `.receive()` operations

Aliased to `.w()`.

#### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| *t* | Float | Yes | Time to wait for, in seconds |
| *onDone* | Function | No | Error-first callback to run when the wait is over |

#### Return Value

Returns the AT instance (`this`).

#### Example

See examples for `.seq()` for examples of `.wait()` used in context.

### f(formatString)

Alias for
[`format()`](https://developer.electricimp.com/squirrel/string/format).  This
is expected to be a commonly used functions by deriving classes and application
code, so this shorter alias is added for convenience.

## Instance Properties

### acc

Short for "accumulator", this property is meant to be used, if necessary, by
`onData()` callbacks to maintain state throughout the course of a `.receive()`
operation.  It is reset to `null` whenever a `.receive()` operation completes.
An `onData()` callback can check if `acc ==  null` to check that this is the
first time it is executing during this operation, and it may then initialise
state into `acc`, which can be modified in other calls to the `onData()`
callback.

Note that `acc` cannot be used from `onDone()`, since it will have already been
cleared.  To use the value of `acc` in `onDone()`, the `.receive()` operation
should be ended by returning `acc` from `onData()`, or by passing `acc` to
`.stop()`;

#### Example

You are sending a power down command to a device, and for whatever reason you
want to count how many other extra responses you receive before the final
"POWER DOWN" response, and log the number at the end.  This example will
illustrate two ways to do so: one without using `acc`, and the other with using
`acc`.

```squirrel
// Define our callback for the end
function onDone(err, count) {
  if (err) {
    // Handle the error...
  }
  server.log(format("Got %d extra responses before power down.", count));
}

// Define an `onData()` callback
// This version is a closure over the local variable `count`
local count = 0;
function countResponsesUntilPowerDown1(data) {
  if (data == "POWER DOWN") return count;
  else {
    // We have received an extra response while waiting for power down, count it
    count++;
    return AT.CB_REPEAT;
  }
}

// Define an `onData()` callback
// This version will use `acc`, to be repeatable
function countResponsesUntilPowerDown2(data) {
  // Initialise state (count)
  if (at.acc == null) at.acc = 0;
  // When we get "POWER DOWN", return the count (to be passed to the `onDone`
  // callback)
  if (data == "POWER DOWN") return at.acc;
  else {
    // We have received an extra response while waiting for power down, count it
    at.acc++;
    return AT.CB_REPEAT;
  }
}

// This will work well - but only once.  The second time
// `countResponsesUntilPowerDown1()` is used, its state may already be non-zero
// from the last time.
at.cmd("AT+PWDWN\r", countResponsesUntilPowerDown1, onDone);

// ...

// `countResponsesUntilPowerDown2()` is repeatable/reusable.  This is because
// the state stored in `acc` is reset by the AT instance when each `.receive()`
// completes.
at.cmd("AT+PWDWN\r", countResponsesUntilPowerDown2, onDone);
```

## Class Properties

### DFLT\_TIMEOUT

The default timeout for `.receive()` operations, if one is not explicitly
configured for the instance by passing it to the constructor.  The value is 60
seconds.

### CB\_REPEAT

A constant defined to be used as a return value from `onData()` callbacks, to
indicate that the same callback should be used again to handle the next
available piece of data.

### Errors

#### ERR\_TIMEOUT

An error message string, passed to `onDone()` callbacks when a `.receive()`
operation times out.

---

#### ERR\_BUSY

An error message string, thrown when attempting to `.send()` to the AT partner
while already busy with a `.receive()` operation.

### `.expect()` Flags

#### NO\_FLAGS

Just `0`.  Using this constant can make code more readable when you need
to provide a value for `flags`, but you don't care to actually set any, for
example when using the `n` argument of `.expect()`.  See example below.

##### Example

```squirrel
// Returns an onData callback that expects to see a number, then "OK"
expect([regexp(@"^\d+$"), "OK"]);

// Returns an onData callback that expects to see a number, then "OK"
// Will pass on the number to the onDone callback
expect([regexp(@"^\d+$"), "OK"], AT.NO_FLAGS, 0);

// (equivalently), less readable
expect([regexp(@"^\d+$"), "OK"], 0, 0);

// (equivalently), less readable
expect([regexp(@"^\d+$"), "OK"], null, 0);
```

---

#### UNORDERED

Flag for controlling behaviour of `onData()` callbacks generated by
`.expect()`.  Indicates that expected values should be allowed to arrive in any
order.

##### Example

```squirrel
// Returns an onData callback that expects to see A, then B, then C
expect(["A", "B", "C"]);

// Returns an onData callback that expects to see exactly A, B, and C in any
// order
expect(["A", "B", "C"], AT.UNORDERED);
```

---

#### IGNORE\_NON\_MATCHING

Flag for controlling behaviour of `onData()` callbacks generated by
`.expect()`.  Indicates that unexpected values should be ignored, rather than
treated as unexpected errors.

##### Example

```squirrel
// onData callback that expects to see 1 "OK" only
expect("OK");

// onData callback that expects to see 1 "OK", but may will silently ignore any
// other responses that come before then
expect("OK", AT.IGNORE_NON_MATCHING);
```

---

#### ALLOW\_REPEATS

Flag for controlling behaviour of `onData()` callbacks generated by
`.expect()`.  Relevant only when `AT.IGNORE_NON_MATCHING` is not set.  When
`AT.UNORDERED` is also set, this flag will cause the callback to allow seeing
multiple responses matching each element of `expected`.  When matching in an
ordered fashion, this will flag will allow repeated responses matching the same
(current) `expected` element before moving onto the next one.

##### Example

```squirrel
// Returns an onData callback that expects to see A, then B, then C
expect(["A", "B", "C"]);

// Returns an onData callback that expects to see 1 or more A`s, then one or
// more B's, then one or more C's
expect(["A", "B", "C"], AT.ALLOW_REPEATS);

// Returns an onData callback that expects to see exactly 1 A, 1 B, and 1 C, in
// any order
expect(["A", "B", "C"], AT.UNORDERED);

// Returns an onData callback that expects to see at least 1 A, B, and C, in
// any order.  It will complete a corresponding receive operation as soon as it
// has seen at least 1 of each.
expect(["A", "B", "C"], AT.UNORDERED | AT.ALLOW_REPEATS);
```

---

#### COLLECT\_ALL

Flag for controlling behaviour of `onData()` callbacks generated by
`.expect()`.  Indicates that all matching data strings should be collected into
an array to be passed to the `onDone()` callback at the end.  The default (with
`AT.COLLECT_ALL` not set) is to only pass on the last piece of data seen, or,
if the `n` argument is passed to `.expect()`, to pass on the `(n-1)`-th element
only.

##### Example

```squirrel
// A regexp to match an integer
local nRe = regexp("^\d+$");

// Generates an onData callback that expects to see 3 numbers
// Only the last will be passed on to onDone
expect(array(3, nRe));

// Now only the 1st will be passed on to onDone
expect(array(3, nRe), 0);
// (equivalently)
expect(array(3, nRe), AT.NO_FLAGS, 0);

// Now an array containing all 3 numbers in the order they arrived will be
// passed on to onDone
expect(array(3, nRe), AT.COLLECT_ALL);
```

---

#### USE\_MATCH\_RESULT

Flag for controlling behaviour of `onData()` callbacks generated by
`.expect()`.

When passed to `.expect()`, this flag will effect what data the resulting
callback saves/collects to pass on to the `onData()` callback at the end.
Normally, the incoming data/tokens are saved (if  the result of `.match()` is
truthy), but if this flag is set then the result of `.match()` will be saved
instead.  This means that for function-type MatchSpecifications, the result of
the function call will be saved (rather than the incoming data, which was the
input to the function).

##### Example

```squirrel
// Regexp to match a numeric status report
local statusRe = regexp(@"^\+STATUS: (\d+)$");

// Returns result of `regexp.match()`: true
at.match(statusRe, "+STATUS: 12");

// Now using USE_MATCH_RESULT...

// This function will return the parsed integer on a match, and null otherwise
function matchStatus(str) {
  local groups = statusRe.capture(str);
  if (!groups) return null;
  return str.slice(groups[1].begin, groups[1].end).tointeger();
}

// Generates an onData() callback that checks for a status report followed by an "OK"
at.expect([matchStatus, "OK"], AT.USE_MATCH_RESULT, 0);

// Execute a status command, such that the status integer is passed to the into onDone()
at.cmd("AT+STATUS", at.ex([matchStatus, "OK"], AT.USE_MATCH_RESULT, 0), function(err, status) {
  if (err) return server.error("get status failed: " + err);

  // The status integer is now available as the `status` argument
  // ...
});

// Contrast the above to this version
// Here, the raw status string is passed into onDone(), and must be parsed
// there (if required)
at.cmd("AT+STATUS", at.ex([statusRe, "OK"], AT.NO_FLAGS, 0), function(err, data) {
  if (err) return server.error("get status failed: " + err);

  // `data` only contains the raw string response, so must now be parsed
  local results = statusRe.capture(data);
  local status = data.slice(results[1].begin, results[1].end);

  // The status integer is now available as `status`
  // ...
});
```

# License

The AT library is licensed under the [MIT License](LICENSE).
