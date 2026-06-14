#!/usr/bin/env python3
"""
Script de geração automática de manifesto de novas features para o Moblin.
Executado durante o Build Phase do Xcode.
"""

import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

def get_marketing_version() -> str:
    """Extrai MARKETING_VERSION do Base.xcconfig"""
    config_path = Path("Config/Base.xcconfig")
    if not config_path.exists():
        print("⚠️ Base.xcconfig não encontrado. Usando fallback.")
        return "1.0.0"
    
    content = config_path.read_text(encoding="utf-8")
    for line in content.splitlines():
        if line.strip().startswith("MARKETING_VERSION"):
            version = line.split("=")[1].strip()
            return version
    return "1.0.0"

def get_git_features() -> set:
    """Tenta extrair features via Conventional Commits"""
    try:
        # Última tag
        last_tag = subprocess.check_output(
            ["git", "describe", "--tags", "--abbrev=0"], 
            stderr=subprocess.PIPE
        ).decode().strip()
        
        # Commits desde a última tag
        log = subprocess.check_output(
            ["git", "log", f"{last_tag}..HEAD", "--oneline"],
            stderr=subprocess.PIPE
        ).decode()
        
        features = set()
        
        # feat(escopo):
        features.update(re.findall(r'feat\(([^)]+)\):', log))
        # feature: escopo
        features.update(re.findall(r'feature:\s*([a-zA-Z0-9_-]+)', log, re.IGNORECASE))
        
        print(f"✅ Git detectado: {len(features)} features encontradas (última tag: {last_tag})")
        return features
        
    except Exception as e:
        print(f"⚠️ Git não disponível ou shallow clone: {e}")
        print("   → Usando apenas ManualFeatures.json")
        return set()

def main():
    print("=== Moblin New Features Manifest Generator ===")
    
    root = Path.cwd()
    output_dir = root / "Config"
    output_file = output_dir / "NewFeatures.json"
    manual_file = root / "Config" / "ManualFeatures.json"
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # 1. Versão atual
    version = get_marketing_version()
    
    # 2. Features do Git (com fallback)
    git_features = get_git_features()
    
    # 3. Manifesto Manual
    manual_features = set()
    manual_config = {}
    source = "manual-only"
    
    if manual_file.exists():
        try:
            manual_config = json.loads(manual_file.read_text(encoding="utf-8"))
            manual_features = set(manual_config.get("features", []))
            
            # Respeita flag autoDetectFromGit
            auto_detect = manual_config.get("autoDetectFromGit", True)
            
            if auto_detect:
                all_features = git_features.union(manual_features)
                source = "git+manual"
            else:
                all_features = manual_features
                source = "manual-only"
                
            print(f"✅ ManualFeatures.json carregado: {len(manual_features)} features")
        except Exception as e:
            print(f"❌ Erro ao ler ManualFeatures.json: {e}")
            all_features = git_features
    else:
        all_features = git_features
        print("ℹ️ ManualFeatures.json não encontrado (opcional)")
    
    # 4. Gerar manifesto final
    manifest = {
        "version": version,
        "features": sorted(list(all_features)),
        "generatedAt": datetime.utcnow().isoformat() + "Z",
        "source": source
    }
    
    # 5. Salvar
    output_file.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )
    
    print(f"✅ NewFeatures.json gerado com sucesso!")
    print(f"   Versão: {version}")
    print(f"   Features: {len(manifest['features'])}")
    print(f"   Fonte: {source}")
    print(f"   Arquivo: {output_file}")

if __name__ == "__main__":
    main()
