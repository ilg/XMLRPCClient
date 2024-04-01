# XMLRPCClient

[![Build & Test][buildtest-image]][buildtest-url]
[![Swift Version][swift-image]][swift-url]
[![License][license-image]][license-url]
[![codebeat-badge][codebeat-image]][codebeat-url]

Swift XML-RPC client based on `URLSession.dataTask`.

Uses [XMLRPCCoder](/ilg/XMLRPCCoder/).  Counterpart to [XMLRPCServer](/ilg/XMLRPCServer/).

## Installation

Add this project on your `Package.swift`

```swift
import PackageDescription

let package = Package(
    dependencies: [
        .Package(
            url: "https://github.com/ilg/XMLRPCClient.git", 
            branch: "main"
        )
    ]
)
```

## Usage example

The simplest (at the call site) way to use `XMLRPCClient` is to invoke the XML-RPC methods as if they were methods on 
the `ServerProxy` instance.

```swift
import XMLRPCClient

let client = ServerProxy(session: .shared, url: URL(string: "http://example.com/RPC")!)

let sum: Int32 = try await client.add(Int32(3), Int32(5))
```


## Development setup

Open [Package.swift](Package.swift), which should open the whole package in Xcode.  Tests can be run in Xcode.

Alternately, `swift test` to run the tests at the command line.

Use `bin/format` to auto-format all the Swift code.

[buildtest-image]:https://github.com/ilg/XMLRPCClient/actions/workflows/build-and-test.yml/badge.svg
[buildtest-url]:https://github.com/ilg/XMLRPCClient/actions/workflows/build-and-test.yml
[swift-image]:https://img.shields.io/badge/Swift-5.8-green.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
[codebeat-image]: https://codebeat.co/badges/a4fc18b2-c809-4202-acb4-b06dddd621a7
[codebeat-url]: https://codebeat.co/projects/github-com-ilg-xmlrpcclient-main
