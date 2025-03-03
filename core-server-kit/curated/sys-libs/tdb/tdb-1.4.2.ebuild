# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

PYTHON_COMPAT=( python3_{5,6,7} )
PYTHON_REQ_USE="threads(+)"

inherit waf-utils multilib-minimal python-single-r1

DESCRIPTION="A simple database API"
HOMEPAGE="https://tdb.samba.org/"
SRC_URI="https://www.samba.org/ftp/tdb/${P}.tar.gz"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="*"
IUSE="python"

REQUIRED_USE="${PYTHON_REQUIRED_USE}"

RDEPEND="!elibc_FreeBSD? ( dev-libs/libbsd[${MULTILIB_USEDEP}] )
	python? ( ${PYTHON_DEPS} )"
DEPEND="
${RDEPEND}
${PYTHON_DEPS}
app-text/docbook-xml-dtd:4.2"

WAF_BINARY="${S}/buildtools/bin/waf"

RESTRICT="test"

src_prepare() {
	default
python_fix_shebang .
multilib_copy_sources
}

multilib_src_configure() {
local extra_opts=()
if ! multilib_is_native_abi || ! use python; then
extra_opts+=( --disable-python )
fi
waf-utils_src_configure \
"${extra_opts[@]}"
}

multilib_src_compile() {
# need to avoid parallel building, this looks like the sanest way with waf-utils/multiprocessing eclasses
unset MAKEOPTS
waf-utils_src_compile
}

multilib_src_test() {
# the default src_test runs 'make test' and 'make check', letting
# the tests fail occasionally (reason: unknown)
emake check
}

multilib_src_install() {
waf-utils_src_install
}
