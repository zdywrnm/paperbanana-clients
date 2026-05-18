App<IAppOption>({
  globalData: {
    launchTime: Date.now(),
  },
  onLaunch() {
    wx.setStorageSync('paperbanana_last_launch', Date.now())
  },
})
