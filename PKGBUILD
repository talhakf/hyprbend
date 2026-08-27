# Maintainer: kosmosys
pkgname=hyprbend
pkgver=0.1.0
pkgrel=1
pkgdesc="Automatic screen rotation and keyboard toggle for 2-in-1 laptops on Hyprland"
arch=('any')
url="https://github.com/kosmosys/hyprbend"
license=('MIT')
depends=('hyprland' 'iio-sensor-proxy' 'bash' '7zip' 'curl')
makedepends=()
source=('hyprbend' 'hyprbend-check' 'hyprbend-fix' 'hyprbend-report' 'hyprbend-detect.sh' 'hyprbend.service')
sha256sums=('SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP' 'SKIP')
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
}
