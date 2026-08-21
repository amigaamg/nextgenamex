import { NextResponse } from 'next/server'

export async function GET() {
  return NextResponse.json({
    status: 'ok',
    service: 'amexan-design',
    timestamp: new Date().toISOString()
  })
}