# Distributed under the terms of the GNU General Public License v2

EAPI="5"

PYTHON_COMPAT=( python2_7 )

inherit python-single-r1

DESCRIPTION="Korean Hangul engine for IBus"
HOMEPAGE="https://github.com/libhangul/ibus-hangul/wiki"
SRC_URI="https://github.com/libhangul/${PN}/releases/download/${PV}/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~*"

IUSE="+nls"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="
	${PYTHON_DEPS}
	>=app-i18n/ibus-1.4[python,${PYTHON_USEDEP}]
	>=app-i18n/libhangul-0.1
	=dev-python/pygobject-2*[${PYTHON_USEDEP}]
	=dev-python/pygtk-2*[${PYTHON_USEDEP}]
	nls? ( virtual/libintl )
"
DEPEND="
	${RDEPEND}
	virtual/pkgconfig
	nls? (
		dev-util/intltool
		>=sys-devel/gettext-0.17
	)
"

DOCS="AUTHORS ChangeLog NEWS README"

src_prepare() {
	sed -ie "s:python:${EPYTHON}:" \
		setup/ibus-setup-hangul.in || die
}

src_configure() {
	econf $(use_enable nls)
}
