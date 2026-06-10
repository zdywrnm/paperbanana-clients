import { copyImageUrl } from '../../utils/media'

Component({
  options: {
    styleIsolation: 'apply-shared',
  },

  properties: {
    stages: {
      type: Array,
      value: [],
    },
    references: {
      type: Array,
      value: [],
    },
  },

  methods: {
    previewStageImage(event: WechatMiniprogram.TouchEvent) {
      const url = String(event.currentTarget.dataset.url || '')
      const canPreview = event.currentTarget.dataset.canPreview
      if (!url) return
      if (canPreview === false || canPreview === 'false') {
        copyImageUrl(url)
        return
      }
      wx.previewImage({ current: url, urls: [url] })
    },
  },
})
