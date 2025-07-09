export interface TranslateConfig {
  baseUrl: string
  endpoint?: string
  client?: string | undefined
  isTranslatePa: boolean
}

export interface TranslateResult {
  text: string
  sourceLang: string
  targetLang: string
}

export interface TranslateOptions {
  from?: string
  to: string
  verbose?: boolean
  preferredConfig?: Partial<TranslateConfig>
  randomizeAll?: boolean
}