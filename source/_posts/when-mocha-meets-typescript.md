---
title: 当Mocha和TypeScript偶遇
date: 2019-01-07 17:50:17
tags:
  - typescript
  - mocha
  - unit test
  - node
categories: efficiency
---

不写单元测试的程序猿~~不~~是个好程序猿

反正我是不可能写单元测试的，我怎么可能写单元测试呢

**嗯 真香**

<!-- more -->

事情的起因是上上篇博客，因为尝试了一下Webhooks，所以怎么能不再尝试一下单元测试呢？

### 摩拳擦掌

#### 安装开发环境依赖

```bash
yarn -D add chai mocha ts-node typescript @types/mocha @types/chai
```

+ `typescript`和`ts-node`提供了TypeScript的运行环境
+ `mocha`是我们这次用到的主要测试框架
+ `chai`是我们这次用到的断言库。何谓断言，就是我说它应该是什么，它就应该是什么，如果不是的话，程序就会跑出一个错误。*#嗯 真霸道*
+ `@types/mocha`和`@types/chai`本身对于程序运行没有什么租用，它只是一份声明文件，来说明模块对外公开的方法和属性的类型以及内容。再搭配上`VSCode`，这就是我迷恋TypeScript的原因。 *# 手动狗头*

#### 假设需要测试的函数

需要测试的其实就是一个函数，给定一个输入，我们需要得到想要的输出。所以需要请出求和大神了。

```typescript
// src/add.ts
const add = (a: number, b: number) => {
    return a + b;
}

export {
    add,
}
```

#### 添加npm scripts

这其实是个可有可无的操作，不过我比较喜欢先写好，毕竟磨刀不误砍柴功～

因为`mocha`这个包是安装在项目目录下的，所以直接执行下面的命令会报错：

```bash
>> mocha -r ts-node/register test/**/*.spec.ts
bash: command not found: mocha
```

这是因为在项目目录中安装的npm cli的路径是在`./node_modules/.bin`路径下的，而且不会暴露到环境变量中，所以需要通过完整的路径来访问。

```bash
./node_modules/.bin/mocha -r ts-node/register test/**/*.spec.ts
```

为了不每次执行命令的时候都需要敲这么这么长的命令，我们可以写到`package.json`文件中

```json
// package.json
{
    "scripts": {
        "test": "mocha -r ts-node/register test/**/*.spec.ts"
    }
}
```

这样，在每次需要执行测试的时候只需要执行`npm run test`或`yarn test`就可以执行完测试脚本了。

**在`scirpts`中的`mocha`也没有加上完整路径，这是因为`npm run`命令会把当前目录下的`./node_modules/.bin`暴露到环境变量中**

### 继晷焚膏

到了这一步，我们就可以开始写我们的测试用例了。

```typescript
// test/add.spec.ts
import { add } from '../src/add'
import { expect } from 'chai'

describe('add function test', () => {
    it('1 + 1 should return 2', () => {
        expect(add(1, 1)).to.equal(2);
    });

    it('1 + 1 should not return 3', () => {
        expect(add(1,1)).to.not.equal(3);
    });
});
```

这边给了两个用例：老生常谈的`1+1===2`和`1+1!==3`问题。当然了，`chai`本身还有各种各样的API，具体的看[官方文档](https://www.chaijs.com/api/)即可。

### 万事俱备，只欠东风

```bash
>> yarn test
yarn run v1.10.1
warning package.json: No license field
$ mocha -r ts-node/register test/**/*.spec.ts


  add function test
    ✓ 1 + 1 should return 2
    ✓ 1 + 1 should not return 3


  2 passing (6ms)

✨  Done in 1.53s.
```

嗯 完美 这样只要在提交代码/或发布前执行下测试脚本就能洗洗睡了～

### 我觉得还可以再懒一点

每次都执行下`yarn test`还是有点烦的，而且还容易忘 :(

#### npm hooks

---

**Update at 20190120**

今天发现了一件非常蠢的事情

`npm publish` 本身就是有hook的，所以不需要单独一个`publish:npm`命令

使用`prepublishOnly`即可

参考[npm scripts 之 publish 和 install](http://csbun.github.io/blog/2017/08/npm-scripts/)

---

如果说是在打包或发布前需要执行测试命令，可以通过`pre hook`来实现自动测试。

```json
{
    "scripts": {
        "prebuild": "npm run test",
        "build": "this is build command",
        // 或
        "prepublish:npm": "npm run test",
        "publish:npm": "this is publish command"
    }
}
```

这样，在执行`yarn build`的时候，实际上是执行`yarn prebuild && yarn build`命令。

ps: 用`publish:npm`是为了避免和原生的`npm publish`命令冲突。

#### git hooks

使用git hooks有两种方法

+ 在`.git/hooks/`下添加相对应的shell脚本
+ 使用npm上的`pre-commit`库

简单说一下第二种的步骤：

1. 安装依赖

```bash
yarn -D add pre-commit
```

2. 修改`package.json`文件

```json
{
    "pre-commit": "test"
}
```

3. 之后在执行`git commit`的时候就会先执行`yarn test`。

### 草船借了谁的箭

+ [Mocha](https://mochajs.org/)
+ [Chai](https://www.chaijs.com/)
+ [npm scripts](https://firstdoit.com/no-need-for-globals-using-npm-dependencies-in-npm-scripts-3dfb478908)
+ [npm hooks](https://docs.npmjs.com/misc/scripts)
+ [在pre-commit中运行npm script](https://www.jianshu.com/p/72a45422c4a3)
+ [Git hooks](https://git-scm.com/book/zh/v2/%E8%87%AA%E5%AE%9A%E4%B9%89-Git-Git-%E9%92%A9%E5%AD%90)

