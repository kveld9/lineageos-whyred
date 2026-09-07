# Contexto y Estado del Proyecto: LineageOS 21 (Android 14) para Xiaomi Redmi Note 5 Pro (whyred)

## 1. Objetivo
Desarrollar y mantener un port/bringup experimental de **LineageOS 21 (Android 14)** para el Xiaomi Redmi Note 5 Pro (`whyred`) con parches de seguridad modernos de Google.

---

## 2. Diagnóstico y Arquitectura del Árbol (Híbrido)
* **Versión de Android:** Android 14 (`PLATFORM_VERSION=14`, `BUILD_ID=AP2A.240905.003`).
* **Base de LineageOS:** Rama `lineage-21.0`.
* **Capa común SDM660 (Oficial LineageOS 21):**
  * `device/xiaomi/sdm660-common` (rama `lineage-21`)
  * `kernel/xiaomi/sdm660` (rama `lineage-21`)
  * `hardware/xiaomi` (rama `lineage-21`)
  * `vendor/xiaomi/sdm660-common` (rama `lineage-21`)
* **Capa específica whyred (Base LineageOS 20 en adaptación):**
  * `device/xiaomi/whyred` (rama local `lineage-21` basada en `lineage-20`)
  * `vendor/xiaomi/whyred` (rama local `lineage-21` basada en `lineage-20`)

---

## 3. Estado del Hardware y Entorno (Arch Linux / CachyOS)
* **CPU:** AMD Ryzen 7 5700G (8 núcleos / 16 hilos)
* **RAM:** 32 GB
* **Almacenamiento:** SSD NVMe con ~250 GB libres
* **Ccache:** 50 GB en `~/.ccache`
* **Dependencias:** Multilib y librerías de 32 bits activas.

---

## 4. Estado del Bringup
* Sincronización `repo sync` de LineageOS 21 completada con éxito.
* Árboles locales y ramas `lineage-21` creadas.
* Dependencias Soong/Kati validadas (`breakfast whyred` resuelve grafo de dependencias limpio).
* Target: `lineage_whyred-userdebug`.

---

## 5. Comandos para Iniciar la Compilación
Para compilar:
```bash
cd /home/kveld/Documentos/repos/lineageos-whyred
./build_whyred.sh
brunch whyred
# o:
mka bacon
```
