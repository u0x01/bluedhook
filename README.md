# BLUEDHOOK
  本项目支持 `Blued`、`Blued 极速版`。

## 使用说明
要使用本插件，你必须具备以下条件之一
- 你的 iOS 设备已经越狱
设备越狱后可直接安装 deb，安装完毕后立即生效。
- 拥有 Apple 开发者证书或 udid p12 证书
如无开发者证书，可自行通过某些渠道购买 udid p12 证书，然后准备一份已砸壳的「Blued」ipa，然后使用「轻松签」App 注入本插件即可生效（需先删除原版）。

## 支持特性
- 支持闪照转换、防撤回
- 本地 VIP 特性（仅支持高级筛选、消息盒子）
- 支持后台保活、推送（黑魔法实现）
本功能可能较耗电，如不需保活可杀后台结束保活。需要注意的是，杀后台无法还原被撤回的消息。

## 已知问题
- ~~重签后不支持 apns 推送~~
~~同时安装 `Blued`、`Blued 极速版` 并登录同一账号，其中   `Blued` 安装 App Store 版用于接收推送，`Blued 极速版` 使用重签版本。不需要推送的可以忽略这些缺陷。~~
- ~~消息防撤回时必须保持在前台~~
~~错过原始消息后，服务器不会发送原始消息，这是消息通讯模型特性决定的，暂时没有很好的解决办法。~~

## see more
[初入iOSRE - 逆向全国最大同性交友App](https://iosre.com/t/topic/20694)
