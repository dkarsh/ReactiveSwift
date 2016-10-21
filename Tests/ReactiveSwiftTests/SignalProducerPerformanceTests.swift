import XCTest
@testable import ReactiveSwift
import Result

class SignalProducerPerformanceTests: XCTestCase {
	func testNormalStarting() {
		let (signal, observer) = Signal<Int, NoError>.pipe()
		let producer = SignalProducer(signal: signal)
		let nested = (0 ..< 32).reduce(producer) { producer, _ in producer.testMap { $0 + 1 } }

		measure {
			for _ in 0 ..< 1000 {
				let disposable = nested.start()
				observer.send(value: 1)
				disposable.dispose()
			}
		}
	}

	func testStartingWithSharedDisposable() {
		let (signal, observer) = Signal<Int, NoError>.pipe()
		let producer = SignalProducer(signal: signal)
		let nested = (0 ..< 32).reduce(producer) { producer, _ in producer.map { $0 + 1 } }

		measure {
			for _ in 0 ..< 1000 {
				let disposable = nested.start()
				observer.send(value: 1)
				disposable.dispose()
			}
		}
	}
}

extension SignalProducerProtocol {
	/// Lift an unary Signal operator to operate upon SignalProducers instead.
	///
	/// In other words, this will create a new `SignalProducer` which will apply
	/// the given `Signal` operator to _every_ created `Signal`, just as if the
	/// operator had been applied to each `Signal` yielded from `start()`.
	///
	/// - parameters:
	///   - transform: An unary operator to lift.
	///
	/// - returns: A signal producer that applies signal's operator to every
	///            created signal.
	func testLift<U, F>(_ transform: @escaping (Signal<Value, Error>) -> Signal<U, F>) -> SignalProducer<U, F> {
		return SignalProducer { observer, outerDisposable in
			self.producer.startWithSignal { signal, disposable in
				outerDisposable += disposable
				transform(signal).observe(observer)
			}
		}
	}

	/// Map each value in the producer to a new value.
	///
	/// - parameters:
	///   - transform: A closure that accepts a value and returns a different
	///                value.
	///
	/// - returns: A signal producer that, when started, will send a mapped
	///            value of `self.`
	func testMap<U>(_ transform: @escaping (Value) -> U) -> SignalProducer<U, Error> {
		return testLift { $0.map(transform) }
	}
}
