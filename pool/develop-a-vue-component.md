---
title: 开发一个vue插件
date: 2019-03-03 15:17:22
tags:
  - vue
  - npm
categories: vue
---

网上已经一大把开发vue插件的文章了，照着别人的抄也没啥意思，所以就放目录结构以及几篇参考文章吧。

**啊，我好懒**

<!--more-->

### 目录结构

demo：[vue-default-image](https://github.com/Blacate/vue-default-image)

```
├── README.md
├── build # webpack的配置文件
│   ├── webpack.build.js # 打包成插件用的webpack配置文件，入口：src/index.js
│   └── webpack.dev.js   # 开发时使用的webpack配置文件，入口：demo/main.js
├── src   # 开发目录
│   ├── components # 开发的组件
│   │   └── vue-default-image
│   │       ├── default.jpg
│   │       └── index.vue # 开发的组件
│   └── index.js  # 入口文件，用于导出component以及`install`方法
├── demo  # 开发目录，一个单独的vue项目用于开发时预览组件效果，会引用src中的组件
│   ├── App.vue
│   ├── index.html
│   └── main.js
├── dist # 打包目录
│   ├── vue-default-image.js
│   └── vue-default-image.js.map
├── package.json
└── yarn.lock
```

### 参考文章及项目

+ [element](https://github.com/ElemeFE/element)

+ [插件--vuejs](https://cn.vuejs.org/v2/guide/plugins.html)

+ [手摸手，带你封装一个vue component](https://segmentfault.com/a/1190000009090836)

+ [从零开始徒手撸一个vue的toast弹窗组件](https://juejin.im/post/5af55f906fb9a07aae153c1c)