
# Building a Redis-Like Key-Value Store in C

A phased implementation roadmap for building an offline hash table, a binary protocol, an event-driven TCP server, and persistent storage.

---

## Phase 1: The Core Data Structure — Memory

**Goal:** Build a robust hash table that runs entirely offline. Do not implement sockets or networking yet.

### 1. Define the Data Structures

Create the following structures:

- **`Entry`** — stores a key, value, and their sizes.
- **`HashTable`** — stores the buckets array, capacity, and current number of entries.

### 2. Implement a Hashing Algorithm

Implement a fast hash function, such as:

- **djb2** — simple and easy to implement.
- **MurmurHash3** — a stronger option for general-purpose hashing.

The hash function should map string or byte-array keys to bucket indices.

### 3. Implement Basic CRUD Operations

Implement functions to:

- **Set** — insert a new key-value pair or update an existing key.
- **Get** — retrieve a value by key.
- **Delete** — remove an entry by key.

Handle hash collisions using one of these approaches:

- **Separate chaining** — each bucket contains a linked list of entries.
- **Open addressing** — resolve collisions by probing for another slot, such as with linear probing.

### 4. Add Dynamic Resizing

Track the load factor:

`load_factor = size / capacity`

When the load factor reaches **0.75**:

1. Allocate a new bucket array with twice the current capacity.
2. Rehash all existing entries into the new array.
3. Update the hash table to use the new array.
4. Free the old bucket array.

> **Important:** Rehash entries using the new capacity. Do not simply copy the old bucket indices.

### 5. Validate the Hash Table

Write a simple `main()` function that:

1. Generates and inserts **100,000 random keys**.
2. Retrieves the inserted keys and verifies their values.
3. Deletes the keys and confirms they are no longer present.
4. Checks edge cases, including duplicate keys, missing keys, collisions, and empty keys if supported.
5. Runs the program under **Valgrind** to detect memory leaks and invalid memory accesses.

**Phase 1 completion criteria**

- [ ] Insert, retrieve, update, and delete work correctly.
- [ ] Collisions are handled safely.
- [ ] Resizing preserves all entries.
- [ ] Memory ownership and cleanup are correct.
- [ ] Tests pass without memory errors.

---

## Phase 2: The Binary Protocol — Serialization

**Goal:** Define a predictable binary format for encoding commands and responses as byte arrays, ready for network transmission.

### 1. Define Commands

Create a structure representing an incoming command with fields such as:

- `Opcode` — identifies the operation, such as `SET`, `GET`, or `DELETE`.
- `KeyLen` — length of the key in bytes.
- `ValLen` — length of the value in bytes.
- `KeyBytes` — key payload.
- `ValBytes` — value payload.

Treat the structure as a logical representation of the command. Do not send a raw C struct directly over the network, because padding, alignment, and byte order can vary between systems.

### 2. Implement Serialization

Write a function that encodes a response—such as a requested value or a success/error status—into a contiguous byte buffer.

- Use `htons()` for 16-bit integer fields.
- Use `htonl()` for 32-bit integer fields.
- Use the corresponding conversion functions when decoding.
- Define exactly how strings, binary values, status codes, and lengths are represented.

### 3. Implement Deserialization

Write a parser that:

1. Receives a byte buffer and its available length.
2. Reads and validates the command header.
3. Extracts the opcode and payload lengths.
4. Verifies that the complete payload is available.
5. Populates a logical command representation.
6. Rejects malformed or unsupported commands safely.

The parser must never read beyond the supplied buffer. It should also handle incomplete input, since a network read may contain only part of a command.

### 4. Validate the Protocol

Pass raw byte arrays into the parser locally and verify that it reconstructs the intended commands.

Test:

- Valid commands and responses.
- Empty keys or values, if supported.
- Unknown opcodes.
- Truncated headers and payloads.
- Invalid or excessive length fields.
- Extra trailing bytes.
- Maximum supported key and value sizes.

**Phase 2 completion criteria**

- [ ] Commands and responses follow a documented binary format.
- [ ] Integer fields use consistent network byte order.
- [ ] Valid messages decode correctly.
- [ ] Malformed and incomplete messages are handled without crashes.
- [ ] Buffer ownership and allocation rules are documented.

---

## Phase 3: The Event Loop — Networking

**Goal:** Turn the hash table into a concurrent TCP server using Linux `epoll`, without creating a thread per client.

> This phase targets Linux and uses non-blocking sockets with an event-driven I/O model.

### 1. Create a TCP Listener

Set up the server socket using:

- `socket()` — create the socket.
- `bind()` — associate it with a local address and port.
- `listen()` — begin accepting connections.
- `fcntl()` — set the listening socket to `O_NONBLOCK`.

Check every system call for errors and configure socket options where appropriate.

### 2. Build the `epoll` Loop

1. Create an epoll instance using `epoll_create1()`.
2. Register the listening socket with `epoll_ctl()`.
3. Run `epoll_wait()` in the main event loop.
4. Dispatch events for new connections, readable sockets, writable sockets, and closed or failed connections.

Use a clear event-handling structure so connection management and protocol processing remain easy to maintain.

### 3. Track Client State

Create a client structure to track each active connection. It may include:

- Socket file descriptor.
- Input buffer and current length.
- Output buffer and write offset.
- Parser state for incomplete commands.
- Connection status and any required limits.

When a client connects:

1. Accept the connection with `accept()` or `accept4()`.
2. Set the client socket to non-blocking mode.
3. Register it with epoll.
4. Allocate and initialize its client state.

When a client disconnects or encounters a fatal error, remove it from epoll, close the socket, and release its resources.

### 4. Connect the Phases

When a client socket becomes readable:

1. Read available bytes into the client's input buffer.
2. Pass complete messages to the Phase 2 parser.
3. Validate and execute each command against the Phase 1 hash table.
4. Serialize the result into a response buffer.
5. Queue the response for writing.
6. Send as many bytes as the socket can accept.
7. Preserve any unwritten bytes and resume on a later writable event.

**Important:** Non-blocking `read()` and `write()` calls may process fewer bytes than requested or return `EAGAIN`/`EWOULDBLOCK`. TCP also does not preserve message boundaries, so the parser must support partial and multiple messages in the same read.

**Phase 3 completion criteria**

- [ ] Multiple clients can connect without one blocking the others.
- [ ] Partial reads and writes are handled correctly.
- [ ] Multiple commands per connection are supported.
- [ ] Disconnects and socket errors release resources safely.
- [ ] Client buffers and request sizes have defined limits.

---

## Phase 4: Persistence — Storage

**Goal:** Preserve key-value data across server restarts and recover it during startup.

### 1. Implement Graceful Shutdown

Use `sigaction()` to handle `SIGINT` and `SIGTERM`.

The signal handler should do as little as possible—for example, set a `volatile sig_atomic_t` shutdown flag. Let the main event loop observe that flag and perform cleanup safely.

During shutdown:

1. Stop accepting new connections.
2. Finish or discard pending client work according to the server's policy.
3. Save the current data to disk.
4. Close client and listening sockets.
5. Close the epoll descriptor and release remaining resources.

### 2. Implement Point-in-Time Snapshots

Write a function that iterates through every hash-table bucket and writes all key-value pairs to a binary `.rdb` file.

Define a snapshot format containing enough information to identify and validate each record, such as:

- File-format magic and version.
- Record count or another well-defined end-of-file strategy.
- Key length and value length.
- Key bytes and value bytes.
- Optional checksum or integrity metadata.

Use explicit byte-order conversions for numeric fields. Do not dump raw C structs directly to disk.

For reliability, consider writing to a temporary file, checking all writes, flushing and closing it successfully, and then atomically renaming it to the snapshot path.

### 3. Implement the Boot Loader

At server startup:

1. Check whether the `.rdb` file exists.
2. Validate its magic, version, and record structure.
3. Read each record and validate its lengths before allocating memory.
4. Insert each key-value pair into the hash table.
5. Handle truncated or corrupted snapshots without reading out of bounds.
6. Start the epoll loop after loading completes.

Define a clear recovery policy for invalid snapshots, such as failing startup with an error rather than silently starting with empty data.

### 4. Optional: Append-Only File (AOF)

Add an append-only log for write operations.

- Append each `SET` and `DELETE` operation to the log.
- Use a documented record format, such as the Phase 2 command encoding.
- Check write errors and decide when data must be flushed to disk.
- Replay valid log records during startup, in order, after loading the snapshot if both are used.
- Consider log truncation, partial final records, and periodic compaction.

**Phase 4 completion criteria**

- [ ] Graceful shutdown produces a valid snapshot.
- [ ] Restarting the server restores saved values.
- [ ] Corrupted or truncated files are handled safely.
- [ ] Disk write failures are detected.
- [ ] Optional AOF replay restores changes made after the snapshot.

---

## Suggested Project Structure

```text
kv-store/
├── include/
│   ├── hash_table.h
│   ├── protocol.h
│   ├── server.h
│   └── persistence.h
├── src/
│   ├── main.c
│   ├── hash_table.c
│   ├── protocol.c
│   ├── server.c
│   └── persistence.c
├── tests/
│   ├── test_hash_table.c
│   ├── test_protocol.c
│   └── test_persistence.c
├── Makefile
└── README.md
```

Adjust the structure as the project grows. Keep the hash table, protocol, networking, and persistence layers independent where possible.

## Recommended Implementation Order

1. **Memory:** complete and test the hash table.
2. **Protocol:** define the wire format and build safe local parser tests.
3. **Networking:** implement non-blocking client handling and connect commands to the hash table.
4. **Persistence:** add snapshots and startup recovery.
5. **Hardening:** test malformed input, resource limits, failures, and repeated restarts.

The key principle is to make each phase independently testable before integrating it with the next.
