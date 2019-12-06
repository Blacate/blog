---
title: vue默认图片
date: 2018-12-22 16:20:17
tags: 
  - vue
  - image
categories: vue
---

这是一篇迟到了大半年的文章

目前是拖延症晚期患者，始终在与deadline做斗争～

主要是为了解决前后端分离后，后端数据没有回来之前，以及数据回来之后图片加载失败的情况下显示默认图片而不是显示图片加载失败的情况～

<!-- more -->

当时也是尝试了多种方案，折腾了有近半天才找到了一个算完美的解决方案。

#### 需求分析

1. 数据回来之前，显示默认图片
2. 数据回来之后，显示后端给定的图片
3. 如果图片的url无效，则继续显示默认图片

#### 方案一

```vue
<img :src="remoteimg || 'default.jpg'">
```

这种方案只能解决在后端数据回来之前图片区域显示的问题，在后端数据未回来之前`remoteimg` 为`null` 所以显示`default.jpg` 但是，在数据回来之后，`remoteimg` 有值后，`src` 的值就变成了`remoteimg` ，这时，就算`remoteimg` 是个无效的图片，也无法继续使用默认图片。

此方案只能解决需求1以及需求2，因此不算完美

#### 方案二

使用`img` 标签的`onLoad` 以及`onError` 事件

```vue
<img :src="remoteimg || 'default.jpg'" @error="setDefaultImage()" />
```

这样看上去是实现了上面三个需求，但是会存在几个问题：

+ 如果图片请求很慢的话，默认图片和所需要展示的图片中间会有一个很长的过渡
+ 如果图片请求失败了，会闪现出图片请求失败的画面，再换回默认图片，用户体验较差
+ 代码修改成本太高，可以说需要去手动修改大量代码（懒），而且看着也不爽orz

#### 方案三

```vue
<template>
  <img :src="url" :alt="type" :title="itype">
</template>

<script>
export default {
  props: {
    src: String,
    type: String
  },
  data () {
    return {
      url: ''
    }
  },
  created () {
    let defaults = {
      book: require('@/assets/book_default.png'),
      user: require('@/assets/user_default.png')
    }
    this.url = defaults[this.type]
    if (this.src) {
      this.loadImg(this.src)
    }
  },
  methods: {
    loadImg (src) {
      let testImg = new Image()
      testImg.src = src
      testImg.onload = () => {
        this.url = src
      }
    }
  },
  watch: {
    src: function (val, oldVal) {
      this.loadImg(val)
    }
  }
}
</script>
```

这个方法应该算是完美的解决了上面三个需求，可以说算是把方案二抽离出来，不同之处就是在这个方案中使用`new Image()` 方法来判断图片的链接是否有效，而不是通过显示在页面中的图片标签来判断url的有效性。

该组件接受两个参数，一个是`type` 用来控制默认图片的类型（用户头像/书封），一个是`src` 是图片的url，组件内监听src的变化，当发生变化时，触发加载图片事件：初始化一个Image对象，如果图片加载成功的话，则将有效的url赋值给显示在页面中的`image` 标签。

存在的一个问题就是同一张图片会重复加载，不过应该是可以通过浏览器缓存来减少不必要的流量～



感觉当时找到的资料不止这些，因为太过久远，所以都忘记的差不多了～

嗯 我们要全力抵抗拖延症！

