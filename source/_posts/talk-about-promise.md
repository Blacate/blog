---
title: 谈谈promise
date: 2019-08-11 17:14:07
tags:
  - node
  - JavaScript
  - promise
  - callback
categories: JavaScript
---

嗯，今天周末闲着没事，把收藏了好几年的《Javascript Promise 迷你书》给捞出来翻了一遍。顺便来水一篇博客（逃

<!-- more -->

### 什么是Promise

```javascript
const promise = new Promise ((resolve, reject) => {
  console.log('new promise')
  resolve('resolve promise')
  reject('reject promise')
})

console.log('next step')

promise
.then(res => {
  console.log(res)
})
.catch(err => {
  console.log(err)
})

// new promise
// next step
// resolve promise
```

首先来看一段代码，虽然这是一段闭着眼睛就能敲出来的代码，但是这段代码里面还是包括了许多信息：

+ `Promise`是一个构造函数（这就是句废话）
+ 它在实例化的时候需要传一个参数（函数）进去，函数的两个参数`resolve`, `reject`对应了当前`promise`实例变化的两个过程
+ `Promise`是热切的，一旦构造函数被调用，它就会开始执行你交给它的任务
+ `promise`对象上提供了`.then(onFulfilled, onRejected)`方法，在`promise`的状态发生改变后，就会去执行对应的方法
+ `.catch(onRejected)`其实是`.then(undefined, onRejected)`的一个语法糖
+ `promise`的状态一旦发生改变后，是不会再变的。在上文代码中由于先调用了`resolve`方法，`promise`的状态由`Pending`变成了`Fulfilled`，所以就算再调用`reject`方法也不会变成`Rejected`，这也是为什么没有走到`.catch()`的原因
+ …...

所以简单概括下， `promise`有三个状态、两个过程、一个方法。

#### 三个状态

+ `Pending`：`promise`对象刚被创建后的初始化状态
+ `Fulfilled`：在调用`resolve`时，状态会由`Pending`转为`Fulfilled`
+ `Rejected`：在调用`reject`时，状态会由`Pending`转为`Rejected`

其中需要注意的是`Fulfilled`和`Rejected`这两个状态是不可变的，也就是说一旦变成这两个状态之后就再也无法回头了，当然了，也是不能相互转化的。

#### 两个过程

+ `resolve`：`Pending` -> `Fulfilled`
+ `reject`：`Pending` ->` Rejected`

#### 一个方法

+ `.then()`：用于附上回调函数来处理已完成的值或者拒绝的原因

在上面代码中还有个`.catch()`方法，其实这只是`.then(undefined, onRejected)`的别名。

##### then or catch?

为什么要多此一举呢，看看下面的这段代码也许就能明白了。

```javascript
const onRejected = err => console.log('rejected', err)
const throwError = value => new Error(value)

Promise.resolve(1).then(throwError, onRejected)
Promise.resolve(2).then(throwError).catch(onRejected)
Promise.resolve(3).then(throwError, onRejected).then(undefined, onRejected)
```

其中第一个`promise`其实是不完整的，因为它对于`then`回调中抛出的错误是没有办法处理的，它只能处理`.then`之前的`promise`对象的错误。第二个和第三个`promise`实现的功能是一样的，但是显而易见，第二个的思路更清晰一些。

#### 四个静态方法

这四个静态方法是在构造函数上的，所以不跟上面的混在一起。

+ `Promise.resolve(value)` 生成一个状态为`Fulfilled`的`promise`对象

  ```javascript
  const promise = new Promise((resolve, reject) => {
    resolve(value)
  })
  ```

+ `Promise.reject() ` 生成一个状态为`Rejected`的`promise`对象

  ```javascript
  const promise = new Promise((resolve, reject) => {
    reject(value)
  })
  ```

+ `Promise.all([])` 当所有`promise`的状态变为`Fulfilled`或`Rejected`时，才会调用`.then()`

  这个的使用场景还是挺多的，比方说根据一组id到数据库查询对应信息

  ```javascript
  const queryFromDd = (id) => Promise.resolve({id})
  const promises = [1, 2, 3].map(id => queryFromDd(id))
  Promise.all(promises).then(res => console.log(res))
  ```

+ `Promise.race()` 只要有一个`promise`的状态变为`Fulfilled`或`Rejected`，就会调用`.then()`

  这个的使用场景感觉挺少的，至少我几乎没有用过。不过在看书时，想到一个很好的应用场景：长轮询。因为不同客户端对http请求超时时长的设定不一样，所以长轮询需要保证在指定时间结束连接，然后由客户端再次发起连接。

  ```javascript
  const timeoutPromise = (value) => (new Promise(resolve => {
    setTimeout(() => {
      resolve(', 1again')
    }, value);
  }))
  
  const getDataFromUpstream = (timeToWait) => (new Promise(resolve => {
    setTimeout(() => {
      resolve('data')
    }, timeToWait);
  }))
  
  Promise.race([timeoutPromise(200), getDataFromUpstream(300)]).then(res => console.log(res)) // again
  Promise.race([timeoutPromise(200), getDataFromUpstream(100)]).then(res => console.log(res)) // data
  ```

#### Promise方法链

由于每次`promise.then()`调用都会返回一个新创建的promise对象，所以可以写成链式调用

```javascript
const request = url => {
  return Promise.resolve({url}) 
}

request('urlA')
  .then(res => {
    console.log(res)
    return request('urlB')
  })
  .then(res => {
    console.log(res)
    return request('urlC')
  })
  .then(res => {
    console.log(res)
  })
  .catch(err => {
    console.log(res)
  })
```

### 实现`MyPromise`

源码参考自博客[Promise实现原理（附源码）](https://segmentfault.com/a/1190000012664201)

```javascript
// 判断变量是否为函数
const isFunction = (variable) => typeof variable === 'function';

// 定义MyPromise的三种状态
const PENDING = 'Pending';
const FULFILLED = 'Fulfilled';
const REJECTED = 'Rejected';

class MyPromise {
  constructor(handle) {
    if (!isFunction(handle)) {
      throw new Error('MyPromise must accept a function as a parameter');
    }

    // 添加状态
    this._status = PENDING;
    // 添加结果
    this._value = undefined;
    // 添加成功回调函数队列
    this._fulfilledQueues = [];
    // 添加失败回调函数队列
    this._rejectedQueues = [];

    // 执行handle
    try {
      handle(this._resolve.bind(this), this._reject.bind(this));
    } catch (err) {
      this._reject(err);
    }
  }

  // 添加resolve时执行的函数
  _resolve(val) {
    const run = () => {
      // promise状态不可逆
      if (this._status !== PENDING) return;
      // 依次执行成功队列中的函数，并清空队列
      const runFulfilled = (value) => {
        while (this._fulfilledQueues.length) {
          const cb = this._fulfilledQueues.shift();
          cb && cb(value);
        }
      };
      // 依次执行失败队列的函数，并清空队列
      const runRejected = (value) => {
        while (this._rejectedQueues.length) {
          const cb = this._fulfilledQueues.shift();
          cb && cb(value);
        }
      };
      /**
       * 如果resolve的参数为Promise对象，则必须等待该Promise对象状态改变后，
       * 当前Promise的状态才会改变，且取决于参数Promise对象的状态
       */
      if (val instanceof MyPromise) {
        val.then((value) => {
          this._value = value;
          this._status = FULFILLED;
          runFulfilled(value);
        }, (error) => {
          this._value = error;
          this._status = REJECTED;
          runRejected(error);
        });
      } else {
        this._value = val;
        this._status = FULFILLED;
        runFulfilled(val);
      }
    };
    // 为了支持同步的Promise，这里采用异步调用
    setTimeout(() => run(), 0);
  }

  // 添加reject时执行的函数
  _reject(err) {
    if (this._status !== PENDING) return;
    // question: 为什么不需要判断reject的是MyPromise的实例？
    // 依次执行失败队列中的函数，并清空队列
    const run = () => {
      this._status = REJECTED;
      this._value = err;
      while (this._rejectedQueues.length) {
        const cb = this._rejectedQueues.shift();
        cb && cb(err);
      }
    };
    // 为了支持同步的Promise，这里采用异步调用
    setTimeout(() => run(), 0);
  }

  then(onFulfilled, onRejected) {
    const { _value, _status } = this;

    // 返回一个新的Promise对象
    return new MyPromise((onFulfilledNext, onRejectedNext) => {
      // 封装一个成功时执行的函数
      const fulfilled = (value) => {
        try {
          // 如果不是函数，返回的myPromise状态变为fulfilled， 相当于把当前结果交给下一个proimse
          if (!isFunction(onFulfilled)) {
            onFulfilledNext(value);
          } else {
            const res = onFulfilled(value);
            if (res instanceof MyPromise) {
              // 如果当前回调函数返回MyPromise对象，必须等待其状态改变后再执行下一个毁掉
              res.then(onFulfilledNext, onRejectedNext);
            } else {
              // 否则直接将返回结果作为参数，参入下一个then的回调函数，并立即执行下一个then的回调函数
              onFulfilledNext(res);
            }
          }
        } catch (err) {
          // 如果函数执行出错，新的Promise对象的状态为失败
          onRejectedNext(err);
        }
      };
      // 封装一个失败时执行的函数
      const rejected = (error) => {
        try {
          // 如果不是函数，直接把当前结果交给下一个promise
          if (!isFunction(onRejected)) {
            onRejectedNext(error);
          } else {
            const res = onRejected(error);
            if (res instanceof Promise) {
              // 如果当前回调函数返回MyPromise对象，必须等待其状态改变后再执行下一个毁掉
              res.then(onFulfilledNext, onRejectedNext);
            } else {
              // 否则直接将返回结果作为参数，参入下一个then的回调函数，并立即执行下一个then的回调函数
              onFulfilledNext(res);
            }
          }
        } catch (err) {
          // 如果函数执行出错，新的Promise对象的状态为失败
          onRejectedNext(err);
        }
      };

      switch (_status) {
        // 当状态为pending时，讲then方法回调函数加入执行队列等待执行
        case PENDING:
          this._fulfilledQueues.push(fulfilled);
          this._rejectedQueues.push(rejected);
          break;
        // 当状态已经改变时，立即执行对应的回调函数
        case FULFILLED:
          fulfilled(_value);
          break;
        case REJECTED:
          rejected(_value);
          break;
        default:
          break;
      }
    });
  }

  // 添加catch方法
  catch(onRejected) {
    return this.then(undefined, onRejected);
  }

  // 添加finally方法
  finally(cb) {
    return this.then(
      (value) => MyPromise.resolve(cb()).then(() => value),
      (reason) => MyPromise.resolve(cb()).then(() => { throw reason; }),
    );
  }

  // 添加静态resolve方法
  static resolve(value) {
    // 如果参数时MyPromise实例，直接返回这个实例
    if (value instanceof MyPromise) return value;
    return new MyPromise((resolve) => resolve(value));
  }

  // 添加静态reject方法
  static reject(value) {
    // question: 这边为什么不需要判断参数是不是MyPromise实例？
    return new MyPromise((resolve, reject) => reject(value));
  }

  // 添加静态all方法
  static all(list) {
    return new MyPromise((resolve, reject) => {
      // 返回值的集合
      const values = [];
      let count = 0;
      // eslint-disable-next-line no-restricted-syntax
      for (const [i, p] of list.entries()) {
        // 数组参数有可能不是MyPromise实例，所以先调用MyPromisee.resolve转换一下
        // eslint-disable-next-line no-loop-func
        this.resolve(p).then((res) => {
          values[i] = res;
          count += 1;
          // 数组中所有的状态都变成fulfilled时， 返回的MyPromise的状态就变成了fulfilled
          if (count === list.length) resolve(values);
        }, (err) => {
          // 有一个被reject时返回的MyPromise状态就变成了rejected
          reject(err);
        });
      }
    });
  }

  // 添加静态race方法
  static race(list) {
    return new MyPromise((resolve, reject) => {
      // eslint-disable-next-line no-restricted-syntax
      for (const p of list) {
        // 只要有一个实例率先改变状态，新的MyPormise的状态就跟着改变
        this.resolve(p).then((res) => resolve(res), (err) => reject(err));
      }
    });
  }
}
```

### `bluebird`原理

```javascript
/**
 * 假设我们有一个用于缓存的对象，可以设置缓存、读取缓存
 * 这边单独使用cachePool而不是直接放在cache对象中是为了避免this指向问题
 */
const cachePool = {};
const cache = {
  // get方法传入两个参数：缓存key、回调函数
  get(key, cb) {
    // 使用settimeout是为了将同步变成异步
    // 这边有一点要注意的是回调函数函数的参数顺序必须是 (err, data)
    setTimeout(() => cb(undefined, cachePool[key]), 0);
  },
  // set方法传入三个参数：缓存key、缓存value、回调函数
  set(key, value, cb) {
    // 同上
    setTimeout(() => {
      cachePool[key] = value;
      cb(undefined, true);
    }, 0);
  },
};

// 使用回调函数的方式测试是否正常
cache.set('test', 'testResult', () => {
  cache.get('test', (err, res) => console.log(res));
});

// 将单个函数promise化的函数
function promisify(fn) {
  // 返回promise化后的新函数
  // 它的参数是原函数的参数去掉最后一个回调函数
  return function promiseFn(...rest) {
    // 直接返回一个promise
    return new Promise((resolve, reject) => {
      // 按照上文定义，回调函数的两个参数顺序必须为(err, data)，否则会出错
      fn(...rest, (err, data) => {
        if (err) reject(err);
        resolve(data);
      });
    });
  };
}

// 将get，set方法promise化
const getAsync = promisify(cache.get);
const setAsync = promisify(cache.set);

// 测试promisify后的函数是否正常
setAsync('testPromise', 'testPromisevalue')
  .then(() => getAsync('testPromise'))
  .then((data) => console.log(data));

// 将对象上所有的方法promise化
function promisifyAll(obj) {
  // 遍历出对象上所有属性
  Object.keys(obj).forEach((key) => {
    // 只处理是函数的属性
    if (typeof obj[key] === 'function') {
      // 为对象添加(方法名+Async)的方法
      obj[`${key}Async`] = promisify(obj[key]);
    }
  });
}

// 对cache对象上的所有方法prommise化
promisifyAll(cache);

// 测试是否正常
cache.setAsync('testPromisifyAll', 'testPromisifyAllResult')
  .then(() => cache.getAsync('testPromisifyAll'))
  .then((data) => console.log(data));
```

### `Promise`测试

todo

### 参考文章

+ [JavaScript Promise迷你书](http://liubin.org/promises-book/)
+ [征服 JavaScript 面试: 什么是 Promise？](https://www.zcfy.cc/article/master-the-javascript-interview-what-is-a-promise)
+ [Promise实现原理（附源码）](https://segmentfault.com/a/1190000012664201)
+ [bluebird之Promisify原理](https://juejin.im/post/5ab4f4a2f265da239e4e053b)

