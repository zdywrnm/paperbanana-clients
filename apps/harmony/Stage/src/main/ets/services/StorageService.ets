import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const STORE_NAME = 'paperbanana_harmony'
const COOKIE_KEY = 'auth_cookie'
const API_BASE_KEY = 'api_base'

export class StorageService {
  private context: common.UIAbilityContext
  private pref?: preferences.Preferences

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  private async prefs(): Promise<preferences.Preferences> {
    if (!this.pref) {
      this.pref = await preferences.getPreferences(this.context, STORE_NAME)
    }
    return this.pref
  }

  async getCookie(): Promise<string> {
    const pref = await this.prefs()
    return String(await pref.get(COOKIE_KEY, ''))
  }

  async setCookie(cookie: string): Promise<void> {
    const pref = await this.prefs()
    if (cookie.length) {
      await pref.put(COOKIE_KEY, cookie)
    } else {
      await pref.delete(COOKIE_KEY)
    }
    await pref.flush()
  }

  async getApiBase(defaultValue: string): Promise<string> {
    const pref = await this.prefs()
    return String(await pref.get(API_BASE_KEY, defaultValue))
  }

  async setApiBase(value: string): Promise<void> {
    const pref = await this.prefs()
    await pref.put(API_BASE_KEY, value)
    await pref.flush()
  }
}
