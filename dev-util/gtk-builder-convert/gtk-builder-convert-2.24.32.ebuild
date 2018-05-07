# Distributed under the terms of the GNU General Public License v2

EAPI="6"
GNOME_ORG_MODULE="gtk+"
PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE="xml"

inherit gnome.org python-single-r1

DESCRIPTION="Converts Glade files to GtkBuilder XML format"
HOMEPAGE="https://www.gtk.org/"

LICENSE="LGPL-2+"
SLOT="0"
KEYWORDS=""

IUSE=""
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

COMMON_DEPEND="${PYTHON_DEPS}"

# gtk-builder-convert was part of gtk+ until 2.24.10-r1
# man page transitioned in 2.24.31-r1
RDEPEND="${COMMON_DEPEND}
	!<x11-libs/gtk+-2.24.31-r1:2
"

DEPEND="${COMMON_DEPEND}
	app-text/docbook-xml-dtd:4.3
	app-text/docbook-xsl-stylesheets
	dev-libs/libxslt
"

src_configure() { :; }

src_compile() {
	xsltproc -nonet http://docbook.sourceforge.net/release/xsl/current/manpages/docbook.xsl docs/reference/gtk/gtk-builder-convert.xml
}

src_install() {
	doman gtk-builder-convert.1
	python_doscript gtk/gtk-builder-convert
}
