---
title: 在vue项目中使用stylelint
date: 2019-01-19 16:26:25
tags:
  - vue
  - css
  - stylelint
categories: code-style
---

vue cli 脚手架生成的模板里面好像只有js和html的eslint语法检查，但是没有css的。为了代码质量，所以折腾了一个下午给老项目上了stylelint。

<!--more-->

### 安装stylelint

```bash
# 全局安装，分别用npm和yarn安装
npm install -g stylelint 
yarn global add stylelint
# 项目目录安装，安装为开发依赖
npm install --save-dev stylelint
yarn -D add stylelint
```

全局安装的好处是可以直接在命令行中使用`stylelint`命令，坏处就是全局安装后，全局都可以访问（废话）

我个人一般倾向于项目目录安装，这样能够保证npm全局目录的整洁（处女座没救了）。如果要在命令行中使用的话有两种方式：

+ 加上相对路径`./node_modules/.bin/stylelint` 来使用
+ 使用npm scripts来访问：在`package.json`的`scripts`中添加`"stylelint": "stylelint"`，然后使用`npm run stylelint`来使用

### 添加配置文件

#### 创建配置文件

`stylelint`会从`require('package.json').stylelint`，`.stylelintrc[.{json, yaml, js}]`文件，`stylelint.config.js`文件中读取配置，个人习惯使用`.stylelintrc.js`

```bash
touch .stylelintrc.js
```

#### 使用标准配置文件

`stylelint`官方有提供一个标准的配置文件，我们的配置文件可以继承其他的配置文件。先通过`npm`安装它

```bash
yarn -D add stylelint-config-standard
```

然后修改配置文件，`rules`中的规则可以覆盖`stylelint-config-standard`中的规则

```js
module.exports = {
    extends: 'stylelint-config-standard',
    rules: {
       
    }
}
```

#### 忽略某个文件

因为有些文件不想通过stylelint来控制风格，所以可以通过配置文件忽略它

```javascript
module.exports = {
    rules: {},
    ignoreFiles: ['file-to-ignore.css']
}
```

### 在命令行中使用

现在我们可以在命令行中使用`stylelint`了

```bash
# 如果之前是全局安装
stylelint src/App.vue --fix
# 如果是在项目中安装
./node_modules/.bin/stylelint src/App.vue
npm run stylelint src/App.vue
```

`--fix`为自动修复选项，有些错误比方说锁进和空格是可以自动修复，但是有些比如说属性重复，这些就不能重复了，会在命令的输出中打印出来，需要手动修复。

### 在vscode中使用

在插件库中查找`stylelint`安装即可，这样在coding的时候就能自动提示错误了。

### 在vue中使用

使用`stylelint`的最终目的是在多人合作时保证提交的代码的质量，所以最好在使用webpack开发打包时就控制好代码质量。

首先需要安装stylelint的webpack插件

```bash
yarn -D add stylelint-webpack-plugin
```

在`vue.config.js`中修改（如果没有就新建），关于配置文件可以参考[Vue CLI 3 Configuration Reference](https://cli.vuejs.org/config/#global-cli-config)

```js
const StyleLintPlugin = require('stylelint-webpack-plugin');

module.exports = {
    // ...其他配置
    configureWebpack: {
        plugins: [
            new StyleLintPlugin({
                files: ['**/*.{vue,htm,html,css,sss,less,scss,sass}']
            })
        ]
    }
}
```

添加完之后，在执行`yarn serve`或`yarn build`时都会使用`stylelint`来检查代码风格。

### 参考文档

+ [webpack 添加插件](https://vue-loader.vuejs.org/zh/guide/linting.html#stylelint)
+ [如何在Vue+Webpack下配置Stylelint](https://www.jianshu.com/p/8a33aa5e34b5)
+ [Stylelint in .vue](https://juejin.im/post/5a2c19d351882531ba10df83)
+ [stylelint configuration](https://github.com/stylelint/stylelint/blob/master/docs/user-guide/configuration.md)
+ [vue.config.js configure webpack](https://cli.vuejs.org/guide/webpack.html#simple-configuration)