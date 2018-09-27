import { mkdir } from 'fs'

export default () => mkdir('.storage', err => {})
