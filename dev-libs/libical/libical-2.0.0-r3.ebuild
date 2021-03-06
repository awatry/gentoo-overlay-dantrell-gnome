# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit cmake-utils

DESCRIPTION="An implementation of basic iCAL protocols"
HOMEPAGE="https://github.com/libical/libical"
SRC_URI="https://github.com/${PN}/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="|| ( MPL-1.0 LGPL-2.1 )"
SLOT="0/2"
KEYWORDS="~*"

IUSE="doc examples static-libs"

# The GOBJECT_INTROSPECTION build is broken, and upstream has given up
# on it at the moment (it's disabled in Travis). It will probably come
# back in v2.0.1 or later.
# This snippet belongs to RDEPEND:
# introspection? ( dev-libs/gobject-introspection:= )"
RDEPEND="
	dev-libs/icu:=
"
DEPEND="${RDEPEND}
	dev-lang/perl
"

PATCHES=(
	"${FILESDIR}"/${PN}-2.0.0-libical.pc-set-full-version.patch
	"${FILESDIR}"/${PN}-2.0.0-libical.pc-icu-remove-full-paths.patch
	"${FILESDIR}"/${PN}-2.0.0-libical.pc-icu-move-to-requires.patch
	"${FILESDIR}"/${PN}-2.0.0-libical.pc-fix-libdir-location.patch
	"${FILESDIR}"/${PN}-2.0.0-tests.patch #bug 532296
)

src_configure() {
	# See above, introspection is disabled for v2.0.0 at least.
	#local mycmakeargs=(
	#	-DGOBJECT_INTROSPECTION=$(usex introspection true false)
	#)
	use static-libs || mycmakeargs+=( -DSHARED_ONLY=ON )
	cmake-utils_src_configure
}

src_test() {
	local myctestargs=( -j1 )
	cmake-utils_src_test
}

src_install() {
	cmake-utils_src_install

	if use examples; then
		rm examples/CMakeLists.txt || die
		dodoc -r examples
	fi
}
