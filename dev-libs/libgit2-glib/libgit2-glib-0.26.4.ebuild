# Distributed under the terms of the GNU General Public License v2

EAPI="6"
PYTHON_COMPAT=( python{3_4,3_5,3_6,3_7} )
VALA_USE_DEPEND="vapigen"

inherit gnome2 python-r1 vala meson

DESCRIPTION="Git library for GLib"
HOMEPAGE="https://wiki.gnome.org/Projects/Libgit2-glib"

LICENSE="LGPL-2+"
SLOT="0"
KEYWORDS="*"

IUSE="doc python +ssh +vala"
REQUIRED_USE="python? ( ${PYTHON_REQUIRED_USE} )"

# Specify libgit2 dependency with subslot because libgit2 upstream has a habit
# of changing their API in each release in ways that break libgit2-glib
RDEPEND="
	>=dev-libs/gobject-introspection-0.10.1:=
	>=dev-libs/glib-2.44.0:2
	>=dev-libs/libgit2-0.26.0:0/26[ssh?]
	doc? ( >=dev-util/gtk-doc-am-1.11 )
	python? (
		${PYTHON_DEPS}
		dev-python/pygobject:3[${PYTHON_USEDEP}] )
"
DEPEND="${RDEPEND}
	virtual/pkgconfig
	vala? ( $(vala_depend) )
"

src_prepare() {
	use vala && vala_src_prepare
	gnome2_src_prepare
}

src_configure() {
	local emesonargs=(
		-D gtk_doc=$(usex doc true false)
		-D introspection=true
		-D python=true
		-D ssh=$(usex ssh true false)
		-D vapi=$(usex vala true false)
	)
	meson_src_configure
}

src_install() {
	meson_src_install

	if use python ; then
		install_gi_override() {
			python_moduleinto "$(python_get_sitedir)/gi/overrides"
			python_domodule "${S}"/${PN}/Ggit.py
		}
		python_foreach_impl install_gi_override
	fi
}
