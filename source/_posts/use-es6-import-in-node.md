---
title: 在Node中使用ES6 import/export
date: 2019-08-10 14:18:43
tags:
  - es6
  - node
  - import/export
categories: node
---

ES6从出来至今也好几个年头了，虽然在平时写`vue`时用`export/import`用的不亦乐乎，但是上次在看`lodash`源码时用了一下还是给了我当头一棒：`SyntaxError: Unexpected identifier`，然后又跑去琢磨了大半天，发现了几种使用方法：

<!-- more -->

Add demos: https://github.com/Blacate/es6-import-demos

### 方案一：Babel

这应该是目前用的最多的一种解决方式了，使用`babel	`将ES6转换成ES5运行，但是如果只是为了调试代码，每次打包一次还是挺烦的，所以可以使用`@babel/node`来直接运行文件。

#### 安装`babel-node`

```
yarn add @babel/node @babel/core
```

#### 配置`.babelrc`文件

`.babelrc`是babel的配置文件。默认状态下，`babel-node`对于`import/export`是关闭的，所以需要安装指定的preset并配置

```shell
yarn add @babel/preset-env

tee .babelrc <<-'EOF'
{
  "presets": [ "@babel/preset-env" ]
}
EOF
```

#### 运行`babel-node`

这时，使用`babel-node`就可以运行含有`import/export`等ES6语法的文件了。

不过一般情况下，我不喜欢把模块全局安装，所以无法直接在命令行中使用`babel-node index.js`的命令，需要通过以下几种方式来解决：

##### 使用相对路径

在安装上述模块后，通过研究`node_modules`目录不难发现，其中有个`.bin`目录有点意思，其中包括了需要运行的`balbel-node`的可执行文件，所以我们可以通过相对路径的方式来运行：

```shell
./node_modules/.bin/babel-node index.js
```

##### 使用`npx`

> npm 从5.2版开始，增加了 npx 命令。
>
> npx 想要解决的主要问题，就是调用项目内部安装的模块。
>
> npx 的原理很简单，就是运行的时候，会到`node_modules/.bin`路径和环境变量`$PATH`里面，检查命令是否存在。

```shell
npx babel-node index.js
```

##### 使用`package.json`

通过在`package.json`的`scripts`字段中添加命令，也可以使用`node_modules/.bin`中的可执行文件。

```json
{
  "scripts": {
    "start": "babel-node index.js"
  }
}
```

在命令行中执行`yarn start`或`npm run start`即可运行。

这个方法原理其实和`npx`差不多，都会到`node_modules/.bin`中检查命令是否存在。


### 方案二：使用Loader

这是一个不太推荐的方案，因为不同的Node版本可能会出现问题。比方说下面的`loader.mjs`在`Node v9.2`中可以正常使用，但是在`Node v10.15.3`中使用就报错了。当然了，这个文件是`v9.2`官方文档中提供的一个loader文件，不能要求它兼容其他版本的Node，但是，有时候难免会因为其他的原因需要升级Node版本，最后还需要再对这个文件做修改还是挺头疼的。

```javascript
// loader.mjs

import url from 'url';
import path from 'path';
import process from 'process';

// 获取所有Node原生模块名称 
const builtins = new Set(
  Object.keys(process.binding('natives')).filter((str) =>
    /^(?!(?:internal|node|v8)\/)/.test(str))
);

// 配置import/export兼容的文件后缀名
const JS_EXTENSIONS = new Set(['.js', '.mjs']);

// flag执行的resolve规则
export function resolve(specifier, parentModuleURL /*, defaultResolve */) {

  // 判断是否为Node原生模块
  if (builtins.has(specifier)) {
    return {
      url: specifier,
      format: 'builtin'
    };
  }

  // 判断是否为*.js, *.mjs文件
  // 如果不是则，抛出错误
  if (/^\.{0,2}[/]/.test(specifier) !== true && !specifier.startsWith('file:')) {
    // For node_modules support:
    // return defaultResolve(specifier, parentModuleURL);
    throw new Error(
      `imports must begin with '/', './', or '../'; '${specifier}' does not`);
  }
  const resolved = new url.URL(specifier, parentModuleURL);
  const ext = path.extname(resolved.pathname);
  if (!JS_EXTENSIONS.has(ext)) {
    throw new Error(
      `Cannot load file with non-JavaScript file extension ${ext}.`);
  }

  // 如果是*.js, *.mjs文件，封装成ES6 Modules格式
  return {
    url: resolved.href,
    format: 'esm'
  };
}
```

使用以下命令即可运行`index.js`文件。

```shell
node --experimental-modules  --loader ./loader.mjs ./index.js
```




### 方案三：esm

这是相对来说最简单的一种方式，通过`Node`的预加载模块功能，加载loader可以简单高效的使用ES Module。

#### 安装`esm`

```shell
yarn add esm
```

#### 使用`esm`

```shell
node -r esm index.js
```

### 方案四：`.mjs`文件

`.mjs`是区别于`.cjs`的，`.mjs`表示js文件将被作为`ESM`加载，`.cjs`表示js文件将被作为`CommonJs`加载。

在ES Module出来之前，Node使用的模块系统是通过`CommonJs`规范实现的，后来JavaScript 官方又出了一种标准化模块系统：ESM。至于说为什么需要如此泾渭分明的区分这两种使用方式笔者也不思不得其姐ORZ。虽然说两着有挺大的区别的，但是却是可以混合使用的，具体可以看这篇文章[CommonJs 和 ESModule 的 区别整理](https://juejin.im/post/5ae04fba6fb9a07acb3c8ac5).

好了，这不是今天的主题，今天的主题是怎么用…...

将需要运行的js文件后缀名都改成`.mjs`之后，使用`node --experimental-modules index.mjs`就可以正常运行了，不过这对Node的版本是有要求的，需要>=8.9.0，`--experimental-modules`表示启用对`ESM`的支持。

### 方案五：Node v12

这个其实跟上一个的解决方案差不多。在上一个解决方案中，是通过后缀名`.mjs`告诉Node使用`ESM`的方式加载js文件，而在	`Node v12`之后，可以通过`package.json`中的`type`字段指定js是使用`ESM`还是`CommonJs`。

>如果 type 的值为 module 那么 js 文件将被作为 ESM 加载
>如果 type 的值为 commonjs 那么 js 文件将被作为 commonjs 来加载


```json
// package.json
{
  "type": "module",
  "scripts": {
    "start": "node --experimental-modules index.js"
  }
}
```

### 总结

在上面的5种方案中，追根究底其实只有三大类：

+ 使用`babel`打包（方案一）
+ 使用Loader去解析，加载模块（方案二，方案三）
+ 指定type使用esm去加载js文件（方案四，方案五）

就目前来说，

方案一更适合在生产环境使用，通过babel打包后的代码，对于Node版本范围的要求更小，兼容性更佳。

方案二并不推荐使用，在不同的Node版本下，loader文件可能会报错。

方案三对于代码的侵略性最小，上手也是最快的，所以日常开发调试可以使用这种方案。

方案四需要修改大量的文件名，我只是想拜读一下lodash的源码，写两行代码琢磨琢磨，却需要把所有的文件名都改了，惹不起惹不起。

方案五对于Node的版本要求较高，现阶段不是一个很好的选择，因为最新的LTS版本才到v10.16.2，没有必要为了这个升价到v12版本，不过可以玩一玩，过把手瘾。

### 参考文章

+ [npx使用教程](http://www.ruanyifeng.com/blog/2019/02/npx.html)
+ [通过 babel-node 运行 ES6 import/export 语法](https://juejin.im/post/5c4f0590e51d45299a08d2bc)
+ [Node 引入 ESM 新方案](https://juejin.im/post/5c9de140f265da30bd3e3f8f)
+ [How can I use an es6 import in node?](https://stackoverflow.com/questions/45854169/how-can-i-use-an-es6-import-in-node)
+ [Node 9下import/export的丝般顺滑使用](https://cnodejs.org/topic/5a0f2da5f9de6bb0542f090b)