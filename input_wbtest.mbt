///|
test "input decoder buffers split terminal sequences" {
  let decoder = InputDecoder::new()
  let (events1, decoder) = decoder.feed(b"\x1b[200~hello ")
  assert_true(events1 == [])
  assert_true(decoder.has_pending())
  assert_true(!decoder.pending_is_lone_escape())
  let (events2, decoder) = decoder.feed(b"world\x1b[201~\r")
  assert_true(events2 == [Paste("hello world"), Key(Enter)])
  assert_true(!decoder.has_pending())

  let (events3, decoder) = InputDecoder::new().feed(b"\x1b[")
  assert_true(events3 == [])
  let (events4, decoder) = decoder.feed(b"5~")
  assert_true(events4 == [Key(PageUp)])
  assert_true(!decoder.has_pending())

  let (events5, decoder) = InputDecoder::new().feed(b"\xe4")
  assert_true(events5 == [])
  let (events6, decoder) = decoder.feed(b"\xbd\xa0")
  assert_true(events6 == [Key(Char("你"))])
  assert_true(!decoder.has_pending())
}

///|
test "input decoder buffers split alt utf8 and flushes a lone escape key" {
  let (events, decoder) = InputDecoder::new().feed(b"\x1b")
  assert_true(events == [])
  assert_true(decoder.pending_is_lone_escape())
  let (flushed, decoder) = decoder.flush()
  assert_true(flushed == [Key(Escape)])
  assert_true(!decoder.has_pending())

  let (events, decoder) = InputDecoder::new().feed(b"\x1b\xe4")
  assert_true(events == [])
  let (events, decoder) = decoder.feed(b"\xbd\xa0")
  assert_true(events == [Key(Alt("你"))])
  assert_true(!decoder.has_pending())
}

///|
test "input decoder bounds incomplete pending data" {
  let bytes = Bytes::make(4100, b'a')
  let (events, decoder) = InputDecoder::new().feed(
    concat_bytes(b"\x1b[200~", bytes),
  )
  assert_true(events == [UnknownEvent("incomplete input exceeded 4096 bytes")])
  assert_true(!decoder.has_pending())
}
