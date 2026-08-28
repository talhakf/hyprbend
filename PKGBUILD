# Maintainer: kosmosys
pkgname=hyprbend
pkgver=0.1.0
pkgrel=9
pkgdesc="Automatic screen rotation and virtual keyboard for 2-in-1 laptops on Hyprland"
arch=('any')
url="https://github.com/kosmosys/hyprbend"
license=('MIT')
depends=('hyprland' 'iio-sensor-proxy' 'bash' '7zip' 'curl' 'jq')
makedepends=()
source=('hyprbend' 'hyprbend-check' 'hyprbend-fix' 'hyprbend-report' 'hyprbend-detect.sh' 'hyprbend.service' 'KNOWN_ISSUES.md' "Hyprbend.qml::file://$startdir/omarchy-plugin/Hyprbend.qml" "manifest.json::file://$startdir/omarchy-plugin/manifest.json")
sha256sums=('SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP')
install=hyprbend.install

package() {
    # Install main script
    install -Dm755 "$srcdir/hyprbend" "$pkgdir/usr/bin/hyprbend"

    # Install diagnostic script
    install -Dm755 "$srcdir/hyprbend-check" "$pkgdir/usr/bin/hyprbend-check"

    # Install fix script
    install -Dm755 "$srcdir/hyprbend-fix" "$pkgdir/usr/bin/hyprbend-fix"

    # Install report script
    install -Dm755 "$srcdir/hyprbend-report" "$pkgdir/usr/bin/hyprbend-report"

    # Install shared detection library
    install -Dm644 "$srcdir/hyprbend-detect.sh" "$pkgdir/usr/lib/hyprbend/detect.sh"

    # Install systemd user service
    install -Dm644 "$srcdir/hyprbend.service" "$pkgdir/usr/lib/systemd/user/hyprbend.service"

    # Install documentation
    install -Dm644 "$srcdir/KNOWN_ISSUES.md" "$pkgdir/usr/share/doc/hyprbend/KNOWN_ISSUES.md"

    # Install omarchy plugin source (consumed by hyprbend.install via omarchy plugin add)
    install -Dm644 "$srcdir/Hyprbend.qml"  "$pkgdir/usr/share/hyprbend/omarchy-plugin/Hyprbend.qml"
    install -Dm644 "$srcdir/manifest.json" "$pkgdir/usr/share/hyprbend/omarchy-plugin/manifest.json"
}
