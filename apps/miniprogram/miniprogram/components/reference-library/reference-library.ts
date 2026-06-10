import { formatError, requestJson } from '../../utils/api'
import { MANUAL_REFERENCE_LIMIT } from '../../utils/constants'
import { normalizeRetrievedReference, type RetrievedReference } from '../../utils/jobs'

interface LibraryCard extends RetrievedReference {
  selected: boolean
}

Component({
  options: {
    styleIsolation: 'apply-shared',
  },

  properties: {
    // 'diagram' | 'plot'，随生成页所选信息图类别切换
    taskName: {
      type: String,
      value: 'diagram',
      observer(this: any) {
        this.loadLibrary()
      },
    },
    selectedIds: {
      type: Array,
      value: [] as string[],
      observer(this: any) {
        this.refreshCards()
      },
    },
  },

  data: {
    cards: [] as LibraryCard[],
    isLoading: false,
    error: '',
    selectedCount: 0,
    limit: MANUAL_REFERENCE_LIMIT,
  },

  lifetimes: {
    attached() {
      this.loadLibrary()
    },
  },

  methods: {
    // latest-wins：taskName 切换/手动刷新时无条件重新请求，仅最新一次请求的响应可落地
    // （不能用 isLoading 早退——会把加载途中的类别切换静默丢弃，面板停留在旧类别）
    async loadLibrary() {
      const seq = (((this as any).loadSeq as number) || 0) + 1
      ;(this as any).loadSeq = seq
      this.setData({ isLoading: true, error: '' })
      try {
        const data = await requestJson<{ references?: unknown[] }>({
          action: 'referenceLibrary',
          taskName: this.properties.taskName || 'diagram',
          query: '',
          limit: 24,
        })
        if (seq !== (this as any).loadSeq) return
        ;(this as any).references = (data.references || []).map(normalizeRetrievedReference)
        this.refreshCards()
        this.setData({ isLoading: false })
      } catch (error) {
        if (seq !== (this as any).loadSeq) return
        this.setData({ error: formatError(error), isLoading: false })
      }
    },

    refreshCards() {
      const references = ((this as any).references || []) as RetrievedReference[]
      const selectedIds = (this.properties.selectedIds || []) as string[]
      this.setData({
        cards: references.map((item) => ({
          ...item,
          selected: selectedIds.indexOf(item.id) >= 0,
        })),
        selectedCount: selectedIds.length,
      })
    },

    onToggle(event: WechatMiniprogram.TouchEvent) {
      const id = String(event.currentTarget.dataset.id || '')
      if (!id) return
      this.triggerEvent('toggle', { id })
    },

    onRefresh() {
      this.loadLibrary()
    },
  },
})
