---
title: write an npm module with typescript
date: 2019-01-21 18:15:14
tags:
  - npm-module
  - typescript
  - node
categories: node
---

以前一直都觉得写个npm模块是件非常高大上的事情。

直到现在，依旧觉得那是件高大上的事情。

虽然其实也还是挺简单的。

所以，就用TypeScript写了个npm模块的[demo](https://github.com/Blacate/npm-module-calculate-demo)～

<!-- more -->

至于为啥用TypeScript写，是因为配合VSCode的语法提示功能用起来很爽=。=

开发模块总体上来讲是分为四个部分的，分别是：

1. 配置环境

2. 开发代码

3. 测试模块

4. 发布

先来放一个项目目录

```
├── .editorconfig // 编辑器配置文件
├── .eslintignore // eslint需要忽略的文件
├── .eslintrc.js  // eslint配置文件
├── .gitignore    // git不追踪的文件
├── .npmignore    // npm publish时不提交的文件
├── .prettierrc.json // prettier配置文件
├── index.d.ts	  // 项目主入口类型定义文件
├── index.js	  // 项目主入口js文件，暴露dist目录，不需要改动
├── index.ts	  // 项目主入口ts文件，同上
├── lib			  // 项目源码
│   ├── calculate.ts
│   └── index.ts  // lib目录入口文件
├── package.json  
├── test           // 单元测试文件
│   └── calculate.spec.ts
├── tsconfig.json  // tsc配置文件
└── tslint.json	   // tslint配置文件
```

在整个项目目录中，除了`lib`目录是第二步开发和`test`目录是第三步测试需要改动的，其他都是第一步配置环境中的，包括配置npm，git，TypeScript开发环境以及代码风格检查等。

### 配置环境

#### EditorConfig

这个主要是用来在不同的编辑器和IDE之间定义和维护一致的代码风格的。如果是单人开发的话，其实没有太大的必要，按照自己习惯的风格就可以了。

参考[EditorConfig](https://editorconfig.org/)

#### npm

npm的环境分为两个部分，一部分是`package.json`，一部分是`.npmignore`

+ `package.json`

  这个用来定义项目的配置信息以及所需要的各种依赖，可以通过`yarn init` 生成

  ```
  $ yarn init
  yarn init v1.10.1
  question name (tempmodule): npm-module-demo
  question version (1.0.0):
  question description: this is an npm module demo
  question entry point (index.js):
  question repository url:
  question author: Neail
  question license (MIT):
  question private:
  success Saved package.json
  ✨  Done in 37.91s.
  ```

+ `.npmignore`

  这是用来决定在使用npm发布模块时需要忽略掉哪些文件，一般是在最后发布前修改，这边可以先放出来。

  ```
  test/ # 测试文件
  lib/ # 项目源码，发布的模块用的是打包后的代码，所以源码不需要放到模块里面
  package-lock.json
  tslint.json
  tsconfig.json
  .prettierrc
  ```

#### git

通过git/svn来进行版本控制，这个应该是常识，这边使用的是git，先写好`.gitignore`，有需要的可以继续修改。

```
# dependencies
node_modules

# IDE
.idea
.awcache
.vscode

# misc
npm-debug.log
.DS_Store

# tests
coverage
.nyc_output
test-schema.graphql

# dist
dist

# log
yarn-error.log
```

然后通过`git init`初始化项目目录

```shell
git init
git remote add origin git@github.com:Blacate/npm-module-calculate-demo.git
git add .
git commit -m "init project"
git push --set-upstream origin
```

#### TypeScript开发环境

##### TypeScript运行环境

```shell
yarn -D add @types/node ts-node typescript
```

然后创建配置文件`tsconfig.json`

```
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "noImplicitAny": false,
    "removeComments": false,
    "noLib": false,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "target": "es6",
    "sourceMap": false,
    "outDir": "./dist",
    "rootDir": "./lib",
    "skipLibCheck": true
  },
  "include": [
    "lib/**/*"
  ],
  "exclude": [
    "node_modules",
    "**/*.spec.ts"
  ]
}
```

详细配置参考 [tsconfig](https://www.typescriptlang.org/docs/handbook/tsconfig-json.html)

##### 代码检查

```shell
yarn -D add \
babel-eslint eslint eslint-config-alloy \
eslint-plugin-typescript lint-staged \
prettier typescript-eslint-parser tslint
```

参考 [TypeScript代码检查](https://ts.xcatliu.com/engineering/lint.html)

### 测试

```shell
yarn -D add @types/chai @types/mocha chai mocha 
```

