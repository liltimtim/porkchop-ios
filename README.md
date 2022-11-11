# Build Status
[![Swift](https://github.com/liltimtim/porkchop-ios/actions/workflows/swift.yml/badge.svg)](https://github.com/liltimtim/porkchop-ios/actions/workflows/swift.yml)

# PorkChop
Combine based wrapper around URLSession

## Supported Platforms

*iOS 13+*

*MacOS 10.15+*

-------

# Example Usage

There are three parts to using the library

### Step 1 - Instantiate the library

```Swift
    private var networking: PRKChopNetworking = .init()
```

### Step 2 - Create a URLRequest

Create a `URLRequest` using the provided `createRequest` method. 

```Swift
    let request = networking.createRequest(url: URL(string: "https://your_url.com", httpMethod: <method>, body: PRKChopEmptyBody())
```

### Step 3 - Pass the request 

```Swift
        let request = networking.createRequest(url: URL(string: "https://your_url.com", httpMethod: <method>, body: PRKChopEmptyBody())
        networkProvider
            .make(for: request)
            
```

Note that `.make` is an `async` function type that can throw. This method returns a `Data` object type and doesn't assume how you want to transform your data. 

You can chain the response with `.tryTransform(type: <type>)` to be used with `Decodable` type of objects or structs. 


