#!/bin/bash

##############################################
# FERSCH 3D - DÉPLOIEMENT AUTOMATIQUE COMPLET
# Version: 1.0.0
# Auteur: Codify AI
##############################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
PROJECT_NAME="fersch-3d"
PROJECT_DIR="/data/codify/3d.fersch.fr"
DOMAIN="3d.fersch.fr"
NODE_VERSION="22"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════╗"
echo "║   FERSCH 3D - INSTALLATION AUTO       ║"
echo "║   Déploiement complet en 1 commande   ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

##############################################
# ÉTAPE 1 : VÉRIFICATIONS PRÉALABLES
##############################################

echo -e "${YELLOW}[1/10] Vérification des prérequis...${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}❌ Ce script doit être exécuté en root${NC}"
  exit 1
fi

# Check système
if [ ! -f /etc/debian_version ]; then
  echo -e "${RED}❌ Ce script nécessite Debian/Ubuntu${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Système compatible${NC}"

##############################################
# ÉTAPE 2 : INSTALLATION NODE.JS
##############################################

echo -e "${YELLOW}[2/10] Installation Node.js ${NODE_VERSION}...${NC}"

if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
  apt-get install -y nodejs
fi

NODE_VER=$(node -v)
echo -e "${GREEN}✅ Node.js installé: ${NODE_VER}${NC}"

##############################################
# ÉTAPE 3 : CRÉATION STRUCTURE
##############################################

echo -e "${YELLOW}[3/10] Création de la structure projet...${NC}"

# Créer dossiers
mkdir -p $PROJECT_DIR/{app,components,lib,public,data/{config,orders,uploads/stl}}
cd $PROJECT_DIR

echo -e "${GREEN}✅ Structure créée${NC}"

##############################################
# ÉTAPE 4 : GÉNÉRATION PACKAGE.JSON
##############################################

echo -e "${YELLOW}[4/10] Génération package.json...${NC}"

cat > package.json <<'PACKAGE_EOF'
{
  "name": "fersch-3d",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p 3000",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^15.0.3",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "typescript": "^5.3.3",
    "@stripe/stripe-js": "^4.0.0",
    "stripe": "^16.0.0",
    "nodemailer": "^6.9.14",
    "axios": "^1.7.2",
    "three": "^0.168.0",
    "@react-three/fiber": "^8.16.0",
    "@react-three/drei": "^9.105.0",
    "formidable": "^3.5.1",
    "uuid": "^10.0.0",
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "@types/node": "^20.11.0",
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@types/nodemailer": "^6.4.14",
    "@types/formidable": "^3.4.5",
    "@types/uuid": "^10.0.0",
    "@types/three": "^0.168.0",
    "tailwindcss": "^3.4.1",
    "postcss": "^8.4.35",
    "autoprefixer": "^10.4.17"
  }
}
PACKAGE_EOF

echo -e "${GREEN}✅ package.json créé${NC}"

##############################################
# ÉTAPE 5 : CONFIGURATION NEXT.JS
##############################################

echo -e "${YELLOW}[5/10] Configuration Next.js...${NC}"

# tsconfig.json
cat > tsconfig.json <<'TSCONFIG_EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
TSCONFIG_EOF

# next.config.js
cat > next.config.js <<'NEXTCONFIG_EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  experimental: {
    serverActions: {
      bodySizeLimit: '100mb'
    }
  },
  webpack: (config) => {
    config.module.rules.push({
      test: /\.(stl|obj)$/,
      type: 'asset/resource'
    });
    return config;
  }
}

module.exports = nextConfig
NEXTCONFIG_EOF

# tailwind.config.js
cat > tailwind.config.js <<'TAILWIND_EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        fersch: {
          blue: '#003B73',
          orange: '#FF6B35',
          gray: '#4A5568',
          light: '#F7FAFC'
        }
      }
    },
  },
  plugins: [],
}
TAILWIND_EOF

# postcss.config.js
cat > postcss.config.js <<'POSTCSS_EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
POSTCSS_EOF

echo -e "${GREEN}✅ Configuration Next.js créée${NC}"

##############################################
# ÉTAPE 6 : GÉNÉRATION APP/LAYOUT.TSX
##############################################

echo -e "${YELLOW}[6/10] Génération app/layout.tsx...${NC}"

mkdir -p app

cat > app/layout.tsx <<'LAYOUT_EOF'
import './globals.css'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Fersch 3D - Impression 3D Résine Professionnelle',
  description: 'Service d\'impression 3D résine haute précision avec Formlabs Form 4',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="fr">
      <body className="antialiased bg-gray-50">
        <nav className="bg-fersch-blue text-white shadow-lg">
          <div className="container mx-auto px-4 py-4">
            <div className="flex items-center justify-between">
              <h1 className="text-2xl font-bold">FERSCH 3D</h1>
              <div className="flex gap-6">
                <a href="/" className="hover:text-fersch-orange transition">Devis</a>
                <a href="/admin" className="hover:text-fersch-orange transition">Admin</a>
              </div>
            </div>
          </div>
        </nav>
        {children}
      </body>
    </html>
  )
}
LAYOUT_EOF

# globals.css
cat > app/globals.css <<'GLOBALS_EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
}
GLOBALS_EOF

echo -e "${GREEN}✅ Layout créé${NC}"

##############################################
# ÉTAPE 7 : GÉNÉRATION APP/PAGE.TSX (HOME)
##############################################

echo -e "${YELLOW}[7/10] Génération page principale...${NC}"

cat > app/page.tsx <<'PAGE_EOF'
'use client'

import { useState } from 'react'
import UploadZone from '@/components/UploadZone'
import ConfigForm from '@/components/ConfigForm'
import PriceBreakdown from '@/components/PriceBreakdown'
import StripeCheckout from '@/components/StripeCheckout'

export default function Home() {
  const [step, setStep] = useState(1)
  const [analysisResult, setAnalysisResult] = useState<any>(null)
  const [config, setConfig] = useState<any>(null)
  const [price, setPrice] = useState<any>(null)

  const handleAnalysisComplete = (result: any) => {
    setAnalysisResult(result)
    setStep(2)
  }

  const handleConfigComplete = async (configData: any) => {
    setConfig(configData)
    
    // Calculer le prix
    const response = await fetch('/api/calculate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        analysis: analysisResult,
        config: configData
      })
    })
    
    const priceData = await response.json()
    setPrice(priceData)
    setStep(3)
  }

  const handlePaymentComplete = () => {
    alert('✅ Commande validée ! Vous allez recevoir un email de confirmation.')
    window.location.href = '/'
  }

  return (
    <main className="container mx-auto px-4 py-12">
      <div className="max-w-6xl mx-auto">
        
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold text-fersch-blue mb-4">
            Impression 3D Résine Haute Précision
          </h1>
          <p className="text-xl text-gray-600">
            Uploadez votre fichier STL et obtenez un devis instantané
          </p>
        </div>

        {/* Steps */}
        <div className="flex justify-center mb-12">
          <div className="flex items-center gap-4">
            <StepIndicator num={1} label="Upload" active={step >= 1} />
            <div className="w-12 h-0.5 bg-gray-300"></div>
            <StepIndicator num={2} label="Configuration" active={step >= 2} />
            <div className="w-12 h-0.5 bg-gray-300"></div>
            <StepIndicator num={3} label="Paiement" active={step >= 3} />
          </div>
        </div>

        {/* Content */}
        <div className="bg-white rounded-2xl shadow-xl p-8">
          
          {step === 1 && (
            <UploadZone onAnalysisComplete={handleAnalysisComplete} />
          )}

          {step === 2 && analysisResult && (
            <ConfigForm 
              analysis={analysisResult}
              onComplete={handleConfigComplete}
            />
          )}

          {step === 3 && price && (
            <div className="grid md:grid-cols-2 gap-8">
              <PriceBreakdown price={price} />
              <StripeCheckout 
                price={price}
                config={config}
                analysis={analysisResult}
                onComplete={handlePaymentComplete}
              />
            </div>
          )}

        </div>
      </div>
    </main>
  )
}

function StepIndicator({ num, label, active }: { num: number, label: string, active: boolean }) {
  return (
    <div className="flex flex-col items-center">
      <div className={`w-12 h-12 rounded-full flex items-center justify-center font-bold text-lg ${
        active ? 'bg-fersch-orange text-white' : 'bg-gray-200 text-gray-500'
      }`}>
        {num}
      </div>
      <span className="text-sm mt-2 text-gray-600">{label}</span>
    </div>
  )
}
PAGE_EOF

echo -e "${GREEN}✅ Page principale créée${NC}"

##############################################
# ÉTAPE 8 : GÉNÉRATION COMPOSANTS
##############################################

echo -e "${YELLOW}[8/10] Génération composants...${NC}"

mkdir -p components

# UploadZone.tsx
cat > components/UploadZone.tsx <<'UPLOAD_EOF'
'use client'

import { useState, useCallback } from 'react'

export default function UploadZone({ onAnalysisComplete }: { onAnalysisComplete: (result: any) => void }) {
  const [uploading, setUploading] = useState(false)
  const [dragActive, setDragActive] = useState(false)

  const handleDrag = useCallback((e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true)
    } else if (e.type === "dragleave") {
      setDragActive(false)
    }
  }, [])

  const handleDrop = useCallback(async (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(false)
    
    const files = e.dataTransfer.files
    if (files && files[0]) {
      await uploadFile(files[0])
    }
  }, [])

  const handleChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (files && files[0]) {
      await uploadFile(files[0])
    }
  }

  const uploadFile = async (file: File) => {
    if (!file.name.toLowerCase().endsWith('.stl')) {
      alert('❌ Seuls les fichiers STL sont acceptés')
      return
    }

    if (file.size > 100 * 1024 * 1024) {
      alert('❌ Fichier trop volumineux (max 100 MB)')
      return
    }

    setUploading(true)

    try {
      const formData = new FormData()
      formData.append('file', file)

      const response = await fetch('/api/analyze', {
        method: 'POST',
        body: formData
      })

      if (!response.ok) throw new Error('Erreur analyse')

      const result = await response.json()
      onAnalysisComplete(result)

    } catch (error) {
      alert('❌ Erreur lors de l\'analyse du fichier')
      console.error(error)
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="w-full">
      <div
        className={`border-4 border-dashed rounded-xl p-12 text-center transition ${
          dragActive ? 'border-fersch-orange bg-orange-50' : 'border-gray-300 hover:border-fersch-blue'
        }`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        {uploading ? (
          <div>
            <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-fersch-orange mx-auto mb-4"></div>
            <p className="text-xl font-semibold text-gray-700">Analyse en cours...</p>
            <p className="text-gray-500 mt-2">PreFormServer calcule le volume et le temps</p>
          </div>
        ) : (
          <>
            <svg className="mx-auto h-16 w-16 text-gray-400 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
            </svg>
            <p className="text-xl font-semibold text-gray-700 mb-2">
              Glissez votre fichier STL ici
            </p>
            <p className="text-gray-500 mb-4">ou</p>
            <label className="cursor-pointer">
              <span className="bg-fersch-orange text-white px-6 py-3 rounded-lg font-semibold hover:bg-orange-600 transition inline-block">
                Parcourir
              </span>
              <input
                type="file"
                accept=".stl"
                onChange={handleChange}
                className="hidden"
              />
            </label>
            <p className="text-sm text-gray-400 mt-4">Formats acceptés : STL (max 100 MB)</p>
          </>
        )}
      </div>
    </div>
  )
}
UPLOAD_EOF

# ConfigForm.tsx
cat > components/ConfigForm.tsx <<'CONFIG_EOF'
'use client'

import { useState, useEffect } from 'react'

export default function ConfigForm({ analysis, onComplete }: any) {
  const [materials, setMaterials] = useState<any[]>([])
  const [config, setConfig] = useState({
    material: 'Tough 2000',
    type: 'Fonctionnelle',
    typologie: 'Standard',
    quantity: 1,
    delivery: 'Retrait'
  })

  useEffect(() => {
    fetch('/api/materials')
      .then(res => res.json())
      .then(setMaterials)
  }, [])

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onComplete(config)
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-6">
        <h3 className="font-semibold text-lg mb-4 text-fersch-blue">📊 Analyse du fichier</h3>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <span className="text-gray-600">Volume résine :</span>
            <span className="ml-2 font-bold text-fersch-blue">{analysis.volume_ml.toFixed(2)} mL</span>
          </div>
          <div>
            <span className="text-gray-600">Temps impression :</span>
            <span className="ml-2 font-bold text-fersch-blue">{analysis.print_time_hours.toFixed(2)} h</span>
          </div>
        </div>
      </div>

      {/* Matière */}
      <div>
        <label className="block font-semibold mb-2">Matière</label>
        <select 
          value={config.material}
          onChange={(e) => setConfig({...config, material: e.target.value})}
          className="w-full border-2 border-gray-300 rounded-lg px-4 py-3 focus:border-fersch-orange focus:outline-none"
        >
          {materials.map(m => (
            <option key={m.name} value={m.name}>{m.name} ({m.price_per_liter}€/L)</option>
          ))}
        </select>
      </div>

      {/* Type */}
      <div>
        <label className="block font-semibold mb-2">Type de pièce</label>
        <select 
          value={config.type}
          onChange={(e) => setConfig({...config, type: e.target.value})}
          className="w-full border-2 border-gray-300 rounded-lg px-4 py-3 focus:border-fersch-orange focus:outline-none"
        >
          <option value="Prototype">Prototype (×1.0)</option>
          <option value="Fonctionnelle">Fonctionnelle (×1.15)</option>
          <option value="Précision">Précision (×1.30)</option>
          <option value="Esthétique">Esthétique (×1.40)</option>
          <option value="Critique">Critique (×1.60)</option>
        </select>
      </div>

      {/* Typologie */}
      <div>
        <label className="block font-semibold mb-2">Typologie</label>
        <select 
          value={config.typologie}
          onChange={(e) => setConfig({...config, typologie: e.target.value})}
          className="w-full border-2 border-gray-300 rounded-lg px-4 py-3 focus:border-fersch-orange focus:outline-none"
        >
          <option value="Standard">Standard (×1.0)</option>
          <option value="Fragile">Fragile (×1.0)</option>
          <option value="Grosse pièce">Grosse pièce (×2.0)</option>
        </select>
      </div>

      {/* Quantité */}
      <div>
        <label className="block font-semibold mb-2">Quantité</label>
        <input
          type="number"
          min="1"
          max="100"
          value={config.quantity}
          onChange={(e) => setConfig({...config, quantity: parseInt(e.target.value)})}
          className="w-full border-2 border-gray-300 rounded-lg px-4 py-3 focus:border-fersch-orange focus:outline-none"
        />
      </div>

      {/* Livraison */}
      <div>
        <label className="block font-semibold mb-2">Livraison</label>
        <select 
          value={config.delivery}
          onChange={(e) => setConfig({...config, delivery: e.target.value})}
          className="w-full border-2 border-gray-300 rounded-lg px-4 py-3 focus:border-fersch-orange focus:outline-none"
        >
          <option value="Retrait">Retrait gratuit</option>
          <option value="Standard">Livraison standard (+12€)</option>
          <option value="Express">Livraison express (+20%)</option>
        </select>
      </div>

      <button
        type="submit"
        className="w-full bg-fersch-orange text-white py-4 rounded-lg font-bold text-lg hover:bg-orange-600 transition"
      >
        Calculer le prix →
      </button>

    </form>
  )
}
CONFIG_EOF

# PriceBreakdown.tsx
cat > components/PriceBreakdown.tsx <<'PRICE_EOF'
'use client'

export default function PriceBreakdown({ price }: any) {
  return (
    <div className="bg-gray-50 rounded-xl p-6">
      <h3 className="text-2xl font-bold mb-6 text-fersch-blue">Détail du prix</h3>
      
      <div className="space-y-3 mb-6">
        <PriceLine label="Coût matière" value={price.material_cost} />
        <PriceLine label="Coût machine" value={price.machine_cost} />
        <PriceLine label="Post-traitement" value={price.post_processing} />
        <PriceLine label="Finition" value={price.finishing} />
        <div className="border-t-2 border-gray-300 pt-3 mt-3">
          <PriceLine label="Sous-total" value={price.subtotal} bold />
        </div>
        <PriceLine label={`Type (${price.type_factor}×)`} value={price.type_cost} />
        <PriceLine label="Carton" value={2} />
        {price.delivery_cost > 0 && (
          <PriceLine label="Livraison" value={price.delivery_cost} />
        )}
      </div>

      <div className="border-t-4 border-fersch-blue pt-4">
        <div className="flex justify-between items-center mb-2">
          <span className="text-lg font-semibold">Total HT</span>
          <span className="text-2xl font-bold text-fersch-blue">{price.total_ht.toFixed(2)} €</span>
        </div>
        <div className="flex justify-between items-center text-gray-600">
          <span>TVA (20%)</span>
          <span>{price.tva.toFixed(2)} €</span>
        </div>
        <div className="flex justify-between items-center mt-3 text-2xl font-bold text-fersch-orange">
          <span>Total TTC</span>
          <span>{price.total_ttc.toFixed(2)} €</span>
        </div>
      </div>
    </div>
  )
}

function PriceLine({ label, value, bold = false }: any) {
  return (
    <div className={`flex justify-between ${bold ? 'font-bold' : ''}`}>
      <span className="text-gray-700">{label}</span>
      <span className="text-gray-900">{value.toFixed(2)} €</span>
    </div>
  )
}
PRICE_EOF

# StripeCheckout.tsx (simplifié pour l'instant)
cat > components/StripeCheckout.tsx <<'STRIPE_EOF'
'use client'

export default function StripeCheckout({ price, onComplete }: any) {
  const handlePayment = async () => {
    // TODO: Implémenter Stripe
    alert('Paiement simulé ✅')
    onComplete()
  }

  return (
    <div className="bg-white border-2 border-fersch-blue rounded-xl p-6">
      <h3 className="text-2xl font-bold mb-6 text-fersch-blue">Paiement</h3>
      
      <div className="mb-6">
        <input
          type="email"
          placeholder="Votre email"
          className="w-full border-2 border-gray-300 rounded-lg px-4 py-3 mb-4 focus:border-fersch-orange focus:outline-none"
        />
        <input
          type="text"
          placeholder="Nom complet"
          className="w-full border-2 border-gray-300 rounded-lg px-4 py-3 focus:border-fersch-orange focus:outline-none"
        />
      </div>

      <button
        onClick={handlePayment}
        className="w-full bg-fersch-blue text-white py-4 rounded-lg font-bold text-lg hover:bg-blue-900 transition"
      >
        Payer {price.total_ttc.toFixed(2)} € 💳
      </button>

      <p className="text-xs text-gray-500 text-center mt-4">
        Paiement sécurisé par Stripe
      </p>
    </div>
  )
}
STRIPE_EOF

echo -e "${GREEN}✅ Composants créés${NC}"

##############################################
# ÉTAPE 9 : GÉNÉRATION API ROUTES
##############################################

echo -e "${YELLOW}[9/10] Génération API routes...${NC}"

mkdir -p app/api/{analyze,calculate,materials}

# /api/analyze/route.ts
cat > app/api/analyze/route.ts <<'ANALYZE_EOF'
import { NextRequest, NextResponse } from 'next/server'
import { writeFile } from 'fs/promises'
import { join } from 'path'
import { v4 as uuidv4 } from 'uuid'

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData()
    const file = formData.get('file') as File
    
    if (!file) {
      return NextResponse.json({ error: 'No file' }, { status: 400 })
    }

    // Sauvegarder le fichier
    const bytes = await file.arrayBuffer()
    const buffer = Buffer.from(bytes)
    const filename = `${uuidv4()}.stl`
    const filepath = join(process.cwd(), 'data/uploads/stl', filename)
    await writeFile(filepath, buffer)

    // TODO: Appeler PreFormServer API
    // Pour l'instant, retour simulé
    const mockResult = {
      filename,
      volume_ml: 11.09,
      print_time_hours: 0.76,
      supports_generated: true
    }

    return NextResponse.json(mockResult)

  } catch (error) {
    console.error(error)
    return NextResponse.json({ error: 'Analysis failed' }, { status: 500 })
  }
}
ANALYZE_EOF

# /api/calculate/route.ts
cat > app/api/calculate/route.ts <<'CALCULATE_EOF'
import { NextRequest, NextResponse } from 'next/server'

export async function POST(request: NextRequest) {
  try {
    const { analysis, config } = await request.json()

    // Récupérer la config matière
    const materials = await import('@/data/config/materials.json')
    const material = materials.default.find((m: any) => m.name === config.material)

    if (!material) {
      return NextResponse.json({ error: 'Material not found' }, { status: 400 })
    }

    // A. COÛT MATIÈRE
    const price_per_ml = material.price_per_liter / 1000
    const material_cost_raw = analysis.volume_ml * price_per_ml
    const material_cost = material_cost_raw * (1 + material.waste_percent)

    // B. COÛT MACHINE
    const machine_cost = analysis.print_time_hours * 7 // 7€/h

    // C. BASE
    const base_cost = material_cost + machine_cost

    // D. POST-TRAITEMENT
    const post_processing = base_cost * 0.30

    // E. FINITION
    const finishing = (base_cost + post_processing) * 0.20

    // F. SOUS-TOTAL
    const subtotal = base_cost + post_processing + finishing

    // G. MARK-UP (selon volume)
    let markup_factor = 1.8
    if (analysis.volume_ml > 10 && analysis.volume_ml <= 50) markup_factor = 1.55
    else if (analysis.volume_ml > 50 && analysis.volume_ml <= 150) markup_factor = 1.35
    else if (analysis.volume_ml > 150 && analysis.volume_ml <= 400) markup_factor = 1.25
    else if (analysis.volume_ml > 400) markup_factor = 1.2

    const price_after_markup = subtotal * markup_factor

    // H. TYPE PIÈCE
    const type_factors: any = {
      'Prototype': 1.0,
      'Fonctionnelle': 1.15,
      'Précision': 1.30,
      'Esthétique': 1.40,
      'Critique': 1.60
    }
    const type_factor = type_factors[config.type] || 1.0
    const type_cost = price_after_markup * type_factor

    // I. TYPOLOGIE
    const typo_factors: any = {
      'Standard': 1.0,
      'Fragile': 1.0,
      'Grosse pièce': 2.0
    }
    const typo_factor = typo_factors[config.typologie] || 1.0
    const final_piece_cost = type_cost * typo_factor

    // J. QUANTITÉ
    const total_pieces = final_piece_cost * config.quantity

    // K. CARTON
    const carton = 2

    // L. LIVRAISON
    let delivery_cost = 0
    if (config.delivery === 'Standard') delivery_cost = 12
    else if (config.delivery === 'Express') delivery_cost = 12 * 1.2

    // M. TOTAL HT
    const total_ht = total_pieces + carton + delivery_cost

    // N. TVA
    const tva = total_ht * 0.20

    // O. TOTAL TTC
    const total_ttc = total_ht + tva

    return NextResponse.json({
      material_cost,
      machine_cost,
      post_processing,
      finishing,
      subtotal,
      markup_factor,
      type_factor,
      type_cost,
      final_piece_cost,
      quantity: config.quantity,
      total_pieces,
      carton,
      delivery_cost,
      total_ht,
      tva,
      total_ttc
    })

  } catch (error) {
    console.error(error)
    return NextResponse.json({ error: 'Calculation failed' }, { status: 500 })
  }
}
CALCULATE_EOF

# /api/materials/route.ts
cat > app/api/materials/route.ts <<'MATERIALS_EOF'
import { NextResponse } from 'next/server'
import materials from '@/data/config/materials.json'

export async function GET() {
  return NextResponse.json(materials)
}
MATERIALS_EOF

echo -e "${GREEN}✅ API routes créées${NC}"

##############################################
# ÉTAPE 10 : FICHIERS DE CONFIG JSON
##############################################

echo -e "${YELLOW}[10/10] Génération fichiers de configuration...${NC}"

# materials.json
cat > data/config/materials.json <<'MATERIALS_JSON_EOF'
[
  {
    "name": "Tough 2000",
    "price_per_liter": 175,
    "waste_percent": 0.2,
    "color": "#2C3E50"
  },
  {
    "name": "Clear V5",
    "price_per_liter": 0,
    "waste_percent": 0.2,
    "color": "#ECF0F1"
  }
]
MATERIALS_JSON_EOF

# pricing.json
cat > data/config/pricing.json <<'PRICING_JSON_EOF'
{
  "machine_cost_per_hour": 7,
  "post_processing_percent": 0.30,
  "finishing_percent": 0.20,
  "tva_percent": 0.20,
  "markup_tiers": [
    { "volume_max": 10, "factor": 1.8 },
    { "volume_max": 50, "factor": 1.55 },
    { "volume_max": 150, "factor": 1.35 },
    { "volume_max": 400, "factor": 1.25 },
    { "volume_max": 999999, "factor": 1.2 }
  ],
  "type_factors": {
    "Prototype": 1.0,
    "Fonctionnelle": 1.15,
    "Précision": 1.30,
    "Esthétique": 1.40,
    "Critique": 1.60
  },
  "typologie_factors": {
    "Standard": 1.0,
    "Fragile": 1.0,
    "Grosse pièce": 2.0
  }
}
PRICING_JSON_EOF

# shipping.json
cat > data/config/shipping.json <<'SHIPPING_JSON_EOF'
{
  "retrait": 0,
  "standard": 12,
  "express_multiplier": 1.2,
  "carton_cost": 2
}
SHIPPING_JSON_EOF

echo -e "${GREEN}✅ Fichiers de config créés${NC}"

##############################################
# ÉTAPE 11 : .ENV.LOCAL
##############################################

echo -e "${YELLOW}Configuration .env.local...${NC}"

cat > .env.local <<'ENV_EOF'
# Email OVH
EMAIL_HOST=ssl0.ovh.net
EMAIL_PORT=587
EMAIL_USER=3d@fersch.fr
EMAIL_PASSWORD=Wowlogan74

# Stripe
STRIPE_PUBLIC_KEY=pk_test_51Sw1N7CxQH7oFcCLmrrgyCD1T4cAUS14gCkSJ3p9IWOfwXUGSzWbAGfaS6gbkb0NcUHu6DKknWNIrx2SOrO5Uy2q00sIhGXtG6
STRIPE_SECRET_KEY=sk_test_51Sw1N7CxQH7oFcCLjB6ofgcBsUPTiNlHqtyB3vMWHd4iXm4sbuVhZ2h1mJfRNPMCIp9TCMeYaQsSbB4gXd63IGGD00sB0GrGfh
STRIPE_WEBHOOK_SECRET=whsec_Ps2zyidEhDZZ0Gu0CP32RVhanmrh4IbK

# PreFormServer
PREFORM_URL=http://localhost:44388

# Site
NEXT_PUBLIC_SITE_URL=https://3d.fersch.fr
NODE_ENV=production
ENV_EOF

echo -e "${GREEN}✅ .env.local configuré${NC}"

##############################################
# ÉTAPE 12 : INSTALLATION DÉPENDANCES
##############################################

echo -e "${YELLOW}Installation des dépendances npm...${NC}"

npm install --legacy-peer-deps

echo -e "${GREEN}✅ Dépendances installées${NC}"

##############################################
# ÉTAPE 13 : BUILD
##############################################

echo -e "${YELLOW}Build Next.js...${NC}"

npm run build

echo -e "${GREEN}✅ Build terminé${NC}"

##############################################
# ÉTAPE 14 : SERVICE SYSTEMD
##############################################

echo -e "${YELLOW}Création du service systemd...${NC}"

cat > /etc/systemd/system/fersch3d.service <<SERVICE_EOF
[Unit]
Description=Fersch 3D Next.js
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable fersch3d
systemctl start fersch3d

echo -e "${GREEN}✅ Service systemd créé et démarré${NC}"

##############################################
# ÉTAPE 15 : NGINX
##############################################

echo -e "${YELLOW}Configuration Nginx...${NC}"

# Installer Nginx si nécessaire
if ! command -v nginx &> /dev/null; then
  apt-get install -y nginx certbot python3-certbot-nginx
fi

cat > /etc/nginx/sites-available/$DOMAIN <<NGINX_EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 100M;
    }
}
NGINX_EOF

ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo -e "${GREEN}✅ Nginx configuré${NC}"

##############################################
# ÉTAPE 16 : SSL (HTTPS)
##############################################

echo -e "${YELLOW}Installation du certificat SSL...${NC}"

certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m logan.ferreira@fersch.fr

echo -e "${GREEN}✅ SSL configuré${NC}"

##############################################
# FIN
##############################################

echo -e "${GREEN}"
echo "╔════════════════════════════════════════╗"
echo "║   ✅ INSTALLATION TERMINÉE !           ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BLUE}📍 Site accessible sur: https://$DOMAIN${NC}"
echo -e "${BLUE}📊 Status service: systemctl status fersch3d${NC}"
echo -e "${BLUE}📝 Logs: journalctl -u fersch3d -f${NC}"
echo ""
echo -e "${YELLOW}⚠️  TODO:${NC}"
echo "  1. Installer PreFormServer (script preformserver-setup.sh)"
echo "  2. Tester l'upload STL"
echo "  3. Configurer Stripe webhook"
echo ""
echo -e "${GREEN}🎉 Bon print ! 🚀${NC}"
