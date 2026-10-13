# Maintainer: Talha Karanfil <karanfiltalha@hotmail.com>
# Contributor: kosmosys <kosmosys.work@gmail.com>
pkgname=hyprbend
pkgver=0.2.0
pkgrel=1
pkgdesc="Automatic screen/stylus rotation and touch virtual keyboard for 2-in-1 laptops on Hyprland"
arch=('any')
url="https://github.com/talhakf/hyprbend"
license=('MIT')
depends=('hyprland' 'bash' '7zip' 'curl' 'jq' 'gawk' 'wtype' 'python')
optdepends=('iio-sensor-proxy: D-Bus accelerometer proxy (direct IIO fallback built-in)')
makedepends=()
source=('hyprbend' 'hyprbend-check' 'hyprbend-fix' 'hyprbend-report' 'hyprbend-detect.sh' 'hyprbend.service' 'KNOWN_ISSUES.md' 'config.conf.example' 'LICENSE' "Hyprbend.qml::file://$startdir/omarchy-plugin/Hyprbend.qml" "VirtualKeyboard.qml::file://$startdir/omarchy-plugin/VirtualKeyboard.qml" "manifest.json::file://$startdir/omarchy-plugin/manifest.json")
sha256sums=('SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP')
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

    # Install documentation & example config
    install -Dm644 "$srcdir/KNOWN_ISSUES.md" "$pkgdir/usr/share/doc/hyprbend/KNOWN_ISSUES.md"
    install -Dm644 "$srcdir/config.conf.example" "$pkgdir/usr/share/doc/hyprbend/config.conf.example"
    install -Dm644 "$srcdir/LICENSE" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"

    # Install omarchy plugin source (consumed by hyprbend.install via omarchy plugin add)
    install -Dm644 "$srcdir/Hyprbend.qml"        "$pkgdir/usr/share/hyprbend/omarchy-plugin/Hyprbend.qml"
    install -Dm644 "$srcdir/VirtualKeyboard.qml" "$pkgdir/usr/share/hyprbend/omarchy-plugin/VirtualKeyboard.qml"
    install -Dm644 "$srcdir/manifest.json"       "$pkgdir/usr/share/hyprbend/omarchy-plugin/manifest.json"
}
