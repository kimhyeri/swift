// RUN: %target-swift-frontend -swift-version 6 -disable-availability-checking -emit-sil -o /dev/null %s -parse-as-library -enable-experimental-feature TransferringArgsAndResults -verify -import-objc-header %S/Inputs/transferring.h

// REQUIRES: concurrency
// REQUIRES: asserts
// REQUIRES: objc_interop

////////////////////////
// MARK: Declarations //
////////////////////////

@MainActor func transferToMain<T>(_ t: T) async {}
func useValue<T>(_ t: T) {}

/////////////////
// MARK: Tests //
/////////////////

func methodTestTransferringResult() async {
  let x = MyType()
  let y = x.getTransferringResult()
  await transferToMain(x)
  useValue(y)
}

func methodTestTransferringArg() async {
  let x = MyType()
  let s = NSObject()
  let _ = x.getResultWithTransferringArgument(s)  // expected-error {{sending 's' risks causing data races}}
  // expected-note @-1 {{'s' used after being passed as a transferring parameter; Later uses could race}}
  useValue(s) // expected-note {{risks concurrent access}}
}

// Make sure we just ignore the swift_attr if it is applied to something like a
// class.
func testDoesntMakeSense() {
  let _ = DoesntMakeSense()
}

func funcTestTransferringResult() async {
  let x = NSObject()
  let y = transferNSObjectFromGlobalFunction(x)
  await transferToMain(x)
  useValue(y)

  // Just to show that without the transferring param, we generate diagnostics.
  let x2 = NSObject()
  let y2 = returnNSObjectFromGlobalFunction(x2)
  await transferToMain(x2) // expected-error {{sending 'x2' risks causing data races}}
  // expected-note @-1 {{sending 'x2' to main actor-isolated global function 'transferToMain' risks causing data races between main actor-isolated and local nonisolated uses}}
  useValue(y2) // expected-note {{risks concurrent access}}
}

func funcTestTransferringArg() async {
  let x = NSObject()
  transferNSObjectToGlobalFunction(x) // expected-error {{sending 'x' risks causing data races}}
  // expected-note @-1 {{'x' used after being passed as a transferring parameter; Later uses could race}}
  useValue(x) // expected-note {{risks concurrent access}}
}
