---
title: Nest.js中间件踩坑
date: 2019-03-14 18:05:23
tags:
  - node
  - nest.js
  - express
  - middleware
categories: node
---

最近在开发nest.js遇到了实现诸如日志中间件、session中间件的需求。Nest.js是基于express的实现的，而express的中间件模式是直线型，koa的是洋葱圈型，所以在koa上有些很容易实现的功能比如记录获得处理时间在express上要实现就比较麻烦。所以在这边总结几种在Nest.js上实现的方法。

<!--more-->

### koa与express中间件模式对比

#### koa的洋葱圈型

我们先来看一段代码

```javascript
const Koa = require('koa')
const Router = require('koa-router')

const app = new Koa()
const router = new Router()

const printMiddlerware = async (ctx, next) => {
  console.log('before')
  await next()
  console.log('after')
}

const sleep = seconds => new Promise(resolve => setTimeout(() => resolve(), seconds * 1000))

app.use(printMiddlerware)

router.get('/', async ctx => {
  await sleep(3)
  console.log('route handle')
  ctx.body = 'success'
})

app.use(router.routes())
app.use(router.allowedMethods())

app.listen(3000)
```

当我们启动服务并访问的时候，会在控制台中打印一下内容：

```
$ node index.js       
before
// sleep 3 seconds
route handle
after
```

可以看出，在进入`printMiddleware`后，先执行了`await next()`上面的代码，在执行到`await next()`的时候，进入到了`router`的处理部分，当`router`处理完之后，又回到了`printMiddle`中，继续执行`await next()`后面的部分。借鉴一张网上的图片：

![](/uploads/koa-middleware-model.png)

#### express的直线性模型

先看一段代码

```javascript
const express = require('express')
const app = new express()

const printMiddlerware = async (req, res, next) => {
  console.log('before')
  await next()
  console.log('after')
}

const sleep = seconds => new Promise(resolve => setTimeout(() => resolve(), seconds * 1000))

app.use(printMiddlerware)

app.get('/', async (req, res) => {
  await sleep(3)
  console.log('route handle')
  res.send('success')
})

app.listen(3000)
```

启动并访问，打印出的日志如下

```
$ node index.js                      
before
after
// sleep 3 seconds
route handle
```

可以看出，在`express`中，中间件是由上到下执行的，`next`之后继续寻找下一个中间件执行，所以说`express`的中间件模型是直线型的。

### Nest.js框架提供的中间件

#### 实现形式

Nest 中间件可以是一个函数，也可以是一个带有 `@Injectable()` 装饰器的类。实际上这个类里面的实现的`resolve`方法最终还是返回了一个常规中间件函数。

```typescript
// 类式中间件
import { Injectable, NestMiddleware, MiddlewareFunction, Inject, forwardRef } from '@nestjs/common';
import { IndexService } from './graphql/index/index.service';

@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  constructor(
    @Inject(forwardRef(() => IndexService))  // 依赖注入
    private readonly indexService: IndexService,
  ) {}
  resolve(...args: any[]): MiddlewareFunction {
    return (req, res, next) => { // 实际还是一个中间件函数
      console.log('Request...');
      next();
    };
  }
}

// 函数式中间件
export function logger(req, res, next) {
  console.log('Request...');
  next();
};
```

不过相较于函数式中间件，使用类的一个优势就是可以通过依赖注入的方法注入属于同一模块的依赖项。

#### 使用方法

中间件的使用方法也有两种：一种是使用模块类的 `configure()` 方法；一种是使利用实例 `INestApplication` 提供的`use()`方法 。但是需要注意的是，如果是使用`use()`，只能使用函数式中间件

```typescript
// 使用模块类的configure方法
import { Module, NestModule, MiddlewareConsumer } from '@nestjs/common';
import { LoggerMiddleware } from './common/middlewares/logger.middleware';
import { CatsModule } from './cats/cats.module';

@Module({
  imports: [CatsModule],
})
export class ApplicationModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(LoggerMiddleware)
      .forRoutes('/cats');
  }
}

// 使用INestApplication实例的use方法
const app = await NestFactory.create(ApplicationModule);
app.use(logger);
await app.listen(3000);
```

### 日志中间件示例

好了，说了那么多的废话，现在来实现一个日志中间件。由于类式中间件相比函数式中间件更强大，所以这边使用类式中间件。

假定一个需求，需要记录下每个路由处理所需要的时间，如果在`koa`中的话，大概是这样的：

```javascript
module.exports = async (ctx, next) => {
  const startTime = Date.now()
  await next()
  const endTime = Date.now()
  console.log(JSON.stringify({
    startTime,
    endTime,
    runTime: endTime - startTime
  }))
}
```

是不是很简单？是不是很容易理解？然鹅，由于Nest是基于express的，所以不能享受koa中洋葱圈中间件所带来的便利。有个解决办法就是使用中间件把业务路由包裹起来，像这样：

```javascript
const express = require('express')
const app = new express()

app.use((req, res, next) => {
  req.startTime = Date.now()
  next()
})

app.get('/', (req, res, next) => {
  res.send('hello')
  next()
});

app.use((req, res, next) => {
  const startTime = req.startTime
  const endTime = Date.now()
  console.log(JSON.stringify({
    startTime,
    endTime,
    runTime: endTime - startTime
  }))
  next()
})

app.listen( 8888 )
```

但是，这样写其实是存在问题的：

+ 路由处理完后继续`next()`会走到最后的404的错误处理的中间件中
+ Nest框架中没有这样一个地方放中间件。额...场面一度十分尴尬...

其实也不是没有办法来解决，比方说就可以通过改写`res.end`方法，想出这个方法的人也是蛮厉害的了。

```javascript
const loggerMiddlerware = (req, res, next) => {
  const startTime = Date.now()
  const _end = res.end
  res.end = function end(...rest) {
    const endTime = Date.now()
    console.log(JSON.stringify({
      startTime,
      endTime,
      runTime: endTime - startTime
    }))
    _end.apply(res, rest)
  }
}
```

### 使用Nest的拦截器实现一个伪中间件

Nest框架还提供了管道、过滤器、拦截器等

+ 管道用于在路由之前验证或转换客户端传来的数据
+ 过滤器一般放在处理链条的最后，用来处理整个应用程序中的所有抛出的异常
+ 拦截器可以在函数执行之前/之后绑定额外的逻辑

![管道和过滤器](/uploads/nest-pipe-filter.png)

![拦截器](/uploads/nest-interceptor.png)

从上图可以看出，拦截器也是能充当中间件，实现日志中间件的需求，我们来实现一个日志拦截器：

```typescript
// logger.interceptor.ts
import { Injectable, NestInterceptor, ExecutionContext } from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

@Injectable()
export class LoggerInterceptor implements NestInterceptor {
  async intercept(context: ExecutionContext, call$: Observable<any>){
    const startTime = Date.now();
    return call$.pipe(
      tap(() => {
        const endTime = Date.now();
        console.log(JSON.stringify({
          startTime,
          endTime,
          runTime: endTime - startTime,
        }));
      }),
    );
  }
}
```

最后在根模块中全局使用它：

```typescript
// app.module.ts
import { LoggerInterceptor } from './logger.interceptor';
import { Module } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';

@Module({
  providers: [{
    provide: APP_INTERCEPTOR,
    useClass: LoggerInterceptor,
  }],
})
export class AppModule {}
```

### 当遇上`GraphQLModule`

作为一个强迫症，你觉得使用拦截器比hack`res.end`更优雅，于是把所有需要hack的中间件都换成了拦截器并提交了代码。这时候，boss过来又提了个需求：把返回给用户的数据也打印到日志里。

你觉得这只是个小case，可是现实却狠狠的扇了你一巴掌：拦截器获得的数据是没有经过ApolloServer处理过的，也就是说打印出来的数据不是用户最终获得的数据。

最后通过研究`GraphQLModule`和`apollo-server-express`的源码发现，ApolloServer是通过中间件的形式来处理返回数据的，而拦截器的是处在路由函数和中间件函数之间的，嗯..一夜回到解放前。

最后还是回到了中间件，通过`res.write`方法拿到`response.body`

```javascript
const loggerMiddlerware = (req, res, next) => {
  const startTime = Date.now()
  const _end = res.end
  const _write = res.write
  const chunks = []
  res.write = (...restArgs) => {
    chunks.push(new Buffer(restArgs[0]));
    _write.apply(res, restArgs);
  };
  res.end = function end(...rest) {
    const body = Buffer.concat(chunks).toString('utf8');
    const endTime = Date.now()
    console.log(JSON.stringify({
      startTime,
      endTime,
      runTime: endTime - startTime,
      responseBody: body
    }))
    _end.apply(res, rest)
  }
  next()
}
```

### 参考文档

+ [Express 与 koa 中间件模式对比](https://juejin.im/post/59881640f265da3e154b0509)
+ [Nest.js中间件](https://docs.nestjs.cn/5.0/middlewares)
+ [express-middleware-after-routes](https://stackoverflow.com/questions/24258782/node-express-4-middleware-after-routes)

+ [express-logging-response-body](https://stackoverflow.com/questions/19215042/express-logging-response-body)

