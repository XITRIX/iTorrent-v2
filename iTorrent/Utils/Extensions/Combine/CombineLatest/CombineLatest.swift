//
//  CombineLatest.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 04/04/2024.
//

import Combine
import Foundation

public extension Publishers {
    // 5
    static func combineLatest<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, Result>(
        _ publisher1: A,
        _ publisher2: B,
        _ publisher3: C,
        _ publisher4: D,
        _ publisher5: E,
        _ transform: @escaping (A.Output, B.Output, C.Output, D.Output, E.Output) -> Result
    ) -> AnyPublisher<Result, A.Failure>
    where A.Failure == B.Failure,
          B.Failure == C.Failure,
          C.Failure == D.Failure,
          D.Failure == E.Failure
    {
        return Publishers.CombineLatest4(publisher1, publisher2, publisher3, Publishers.CombineLatest(publisher4, publisher5))
            .map { a, b, c, d in
                transform(a, b, c, d.0, d.1)
            }
            .eraseToAnyPublisher()
    }
    
    // 6
    static func combineLatest<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, Result>(
        _ publisher1: A,
        _ publisher2: B,
        _ publisher3: C,
        _ publisher4: D,
        _ publisher5: E,
        _ publisher6: F,
        _ transform: @escaping (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output) -> Result
    ) -> AnyPublisher<Result, A.Failure>
    where A.Failure == B.Failure,
          B.Failure == C.Failure,
          C.Failure == D.Failure,
          D.Failure == E.Failure,
          E.Failure == F.Failure
    {
        return Publishers.CombineLatest4(publisher1, publisher2, publisher3, Publishers.CombineLatest3(publisher4, publisher5, publisher6))
            .map { a, b, c, d in
                transform(a, b, c, d.0, d.1, d.2)
            }
            .eraseToAnyPublisher()
    }
    
    // 7
    static func combineLatest<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, G: Publisher, Result>(
        _ publisher1: A,
        _ publisher2: B,
        _ publisher3: C,
        _ publisher4: D,
        _ publisher5: E,
        _ publisher6: F,
        _ publisher7: G,
        on dispatchQueue: DispatchQueue? = nil,
        _ transform: @escaping (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output, G.Output) -> Result
    ) -> AnyPublisher<Result, A.Failure>
    where A.Failure == B.Failure,
          B.Failure == C.Failure,
          C.Failure == D.Failure,
          D.Failure == E.Failure,
          E.Failure == F.Failure,
          F.Failure == G.Failure
    {
        var publisher = Publishers.CombineLatest4(publisher1, publisher2, publisher3, Publishers.CombineLatest4(publisher4, publisher5, publisher6, publisher7))
            .eraseToAnyPublisher()

        if let dispatchQueue {
            publisher = publisher.receive(on: dispatchQueue)
                .eraseToAnyPublisher()
        }

        return publisher.map { a, b, c, d in
            transform(a, b, c, d.0, d.1, d.2, d.3)
        }.eraseToAnyPublisher()
    }
}

public extension Publishers {
    // 2
    static func combineLatest<A: Publisher, B: Publisher, Result>(
        _ publisher1: A,
        _ publisher2: B,
        _ transform: @escaping (A.Output, B.Output) -> Result
    ) -> AnyPublisher<Result, A.Failure>
    where A.Failure == B.Failure
    {
        return Publishers.CombineLatest(publisher1, publisher2)
            .map { a, b in
                transform(a, b)
            }
            .eraseToAnyPublisher()
    }

    // 3
    static func combineLatest<A: Publisher, B: Publisher, C: Publisher, Result>(
        _ publisher1: A,
        _ publisher2: B,
        _ publisher3: C,
        _ transform: @escaping (A.Output, B.Output, C.Output) -> Result
    ) -> AnyPublisher<Result, A.Failure>
    where A.Failure == B.Failure,
          B.Failure == C.Failure
    {
        return Publishers.CombineLatest3(publisher1, publisher2, publisher3)
            .map { a, b, c in
                transform(a, b, c)
            }
            .eraseToAnyPublisher()
    }

    // 4
    static func combineLatest<A: Publisher, B: Publisher, C: Publisher, D: Publisher, Result>(
        _ publisher1: A,
        _ publisher2: B,
        _ publisher3: C,
        _ publisher4: D,
        _ transform: @escaping (A.Output, B.Output, C.Output, D.Output) -> Result
    ) -> AnyPublisher<Result, A.Failure>
    where A.Failure == B.Failure,
          B.Failure == C.Failure,
          C.Failure == D.Failure
    {
        return Publishers.CombineLatest4(publisher1, publisher2, publisher3, publisher4)
            .map { a, b, c, d in
                transform(a, b, c, d)
            }
            .eraseToAnyPublisher()
    }
}

//public extension Publishers {
//    // 5
//    static func combineLatest<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, Result>(
//        _ publisher1: A,
//        _ publisher2: B,
//        _ publisher3: C,
//        _ publisher4: D,
//        _ publisher5: E,
//        _ transform: @escaping (A.Output, B.Output, C.Output, D.Output, E.Output) -> Result
//    ) -> Publishers.Map<Publishers.CombineLatest5<A, B, C, D, E>, Result>
//        where A.Failure == B.Failure,
//        B.Failure == C.Failure,
//        C.Failure == D.Failure,
//        D.Failure == E.Failure
//    {
//        return Publishers.CombineLatest5(publisher1, publisher2, publisher3, publisher4, publisher5)
//            .map { a, b, c, d, e in
//                transform(a, b, c, d, e)
//            }
//    }
//
//    // 6
//    static func combineLatest<A: Publisher, B: Publisher, C: Publisher, D: Publisher, E: Publisher, F: Publisher, Result>(
//        _ publisher1: A,
//        _ publisher2: B,
//        _ publisher3: C,
//        _ publisher4: D,
//        _ publisher5: E,
//        _ publisher6: F,
//        _ transform: @escaping (A.Output, B.Output, C.Output, D.Output, E.Output, F.Output) -> Result
//    ) -> Publishers.Map<Publishers.CombineLatest6<A, B, C, D, E, F>, Result>
//        where A.Failure == B.Failure,
//        B.Failure == C.Failure,
//        C.Failure == D.Failure,
//        D.Failure == E.Failure,
//        D.Failure == F.Failure
//    {
//        return Publishers.CombineLatest6(publisher1, publisher2, publisher3, publisher4, publisher5, publisher6)
//            .map { a, b, c, d, e, f in
//                transform(a, b, c, d, e, f)
//            }
//    }
//}
