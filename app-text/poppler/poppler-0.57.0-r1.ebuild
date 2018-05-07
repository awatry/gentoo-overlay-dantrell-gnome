# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit cmake-utils flag-o-matic toolchain-funcs xdg-utils

DESCRIPTION="PDF rendering library based on the xpdf-3.0 code base"
HOMEPAGE="https://poppler.freedesktop.org/"
SRC_URI="https://poppler.freedesktop.org/${P}.tar.xz"

LICENSE="GPL-2"
SLOT="0/68"   # CHECK THIS WHEN BUMPING!!! SUBSLOT IS libpoppler.so SOVERSION
KEYWORDS="*"

IUSE="cairo cjk curl cxx debug doc +introspection +jpeg +jpeg2k +lcms nss png qt4 qt5 tiff +utils"

# No test data provided
RESTRICT="test"

COMMON_DEPEND="
	>=media-libs/fontconfig-2.6.0
	>=media-libs/freetype-2.3.9
	sys-libs/zlib
	cairo? (
		dev-libs/glib:2
		>=x11-libs/cairo-1.10.0
		introspection? ( >=dev-libs/gobject-introspection-1.32.1:= )
	)
	curl? ( net-misc/curl )
	jpeg? ( virtual/jpeg:0 )
	jpeg2k? ( media-libs/openjpeg:2= )
	lcms? ( media-libs/lcms:2 )
	nss? ( >=dev-libs/nss-3.19:0 )
	png? ( media-libs/libpng:0= )
	qt4? (
		dev-qt/qtcore:4
		dev-qt/qtgui:4
	)
	qt5? (
		dev-qt/qtcore:5
		dev-qt/qtgui:5
		dev-qt/qtxml:5
	)
	tiff? ( media-libs/tiff:0 )
"
DEPEND="${COMMON_DEPEND}
	virtual/pkgconfig
"
RDEPEND="${COMMON_DEPEND}
	cjk? ( >=app-text/poppler-data-0.4.7 )
"

PATCHES=(
	"${FILESDIR}"/${PN}-0.26.0-qt5-dependencies.patch
	"${FILESDIR}"/${PN}-0.28.1-fix-multilib-configuration.patch
	"${FILESDIR}"/${PN}-0.53.0-respect-cflags.patch
	"${FILESDIR}"/${PN}-0.33.0-openjpeg2.patch
	"${FILESDIR}"/${PN}-0.40-FindQt4.patch
	"${FILESDIR}"/${PN}-0.57.0-disable-internal-jpx.patch
	# From CVE Details:
	# 	https://www.cvedetails.com/product/24992/Freedesktop-Poppler.html?vendor_id=7971
	"${FILESDIR}"/${PN}-0.57.0-CVE-2017-14517.patch
	"${FILESDIR}"/${PN}-0.57.0-CVE-2017-14518.patch
	"${FILESDIR}"/${PN}-0.57.0-CVE-2017-14519.patch
	"${FILESDIR}"/${PN}-0.57.0-CVE-2017-14520.patch
	"${FILESDIR}"/${PN}-0.57.0-CVE-2017-14617.patch
	"${FILESDIR}"/${PN}-0.57.0-CVE-2017-14926.patch
	"${FILESDIR}"/${PN}-0.57.0-CVE-2017-14927.patch
	"${FILESDIR}"/${PN}-0.57.0-CVE-2017-14928.patch
	"${FILESDIR}"/${PN}-0.57.0-CVE-2017-14929.patch
	"${FILESDIR}"/${PN}-0.58.0-CVE-2017-14975.patch
	"${FILESDIR}"/${PN}-0.58.0-CVE-2017-14976.patch
	"${FILESDIR}"/${PN}-0.58.0-CVE-2017-14977.patch
	"${FILESDIR}"/${PN}-0.60.1-CVE-2017-15565.patch
)

src_prepare() {
	cmake-utils_src_prepare

	# Clang doesn't grok this flag, the configure nicely tests that, but
	# cmake just uses it, so remove it if we use clang
	if [[ ${CC} == clang ]] ; then
		sed -i -e 's/-fno-check-new//' cmake/modules/PopplerMacros.cmake || die
	fi

	if ! grep -Fq 'cmake_policy(SET CMP0002 OLD)' CMakeLists.txt ; then
		sed '/^cmake_minimum_required/acmake_policy(SET CMP0002 OLD)' \
			-i CMakeLists.txt || die
	else
		einfo "policy(SET CMP0002 OLD) - workaround can be removed"
	fi

	# we need to up the C++ version, bug #622526, #643278
	append-cxxflags -std=c++11
}

src_configure() {
	xdg_environment_reset
	local mycmakeargs=(
		-DBUILD_GTK_TESTS=OFF
		-DBUILD_QT4_TESTS=OFF
		-DBUILD_QT5_TESTS=OFF
		-DBUILD_CPP_TESTS=OFF
		-DENABLE_SPLASH=ON
		-DENABLE_ZLIB=ON
		-DENABLE_ZLIB_UNCOMPRESS=OFF
		-DENABLE_XPDF_HEADERS=ON
		-DENABLE_LIBCURL="$(usex curl)"
		-DENABLE_CPP="$(usex cxx)"
		-DENABLE_UTILS="$(usex utils)"
		-DSPLASH_CMYK=OFF
		-DUSE_FIXEDPOINT=OFF
		-DUSE_FLOAT=OFF
		-DWITH_Cairo="$(usex cairo)"
		-DWITH_GObjectIntrospection="$(usex introspection)"
		-DWITH_JPEG="$(usex jpeg)"
		-DWITH_NSS3="$(usex nss)"
		-DWITH_PNG="$(usex png)"
		-DWITH_Qt4="$(usex qt4)"
		$(cmake-utils_use_find_package qt5 Qt5Core)
		-DWITH_TIFF="$(usex tiff)"
	)
	if use jpeg; then
		mycmakeargs+=(-DENABLE_DCTDECODER=libjpeg)
	else
		mycmakeargs+=(-DENABLE_DCTDECODER=none)
	fi
	if use jpeg2k; then
		mycmakeargs+=(-DENABLE_LIBOPENJPEG=openjpeg2)
	else
		mycmakeargs+=(-DENABLE_LIBOPENJPEG=none)
	fi
	if use lcms; then
		mycmakeargs+=(-DENABLE_CMS=lcms2)
	else
		mycmakeargs+=(-DENABLE_CMS=)
	fi

	cmake-utils_src_configure
}

src_install() {
	cmake-utils_src_install
}
