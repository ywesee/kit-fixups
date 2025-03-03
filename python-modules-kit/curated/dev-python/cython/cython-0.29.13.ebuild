# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python2_7 python3_{5,6,7} pypy{,3} )
PYTHON_REQ_USE="threads(+)"

inherit distutils-r1 toolchain-funcs elisp-common

DESCRIPTION="A Python to C compiler"
HOMEPAGE="https://cython.org https://pypi.org/project/Cython/
	https://github.com/cython/cython"
SRC_URI="https://github.com/cython/cython/archive/${PV}.tar.gz -> ${P}.gh.tar.gz"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="*"
IUSE="doc emacs test"
RESTRICT="!test? ( test )"

RDEPEND="
	emacs? ( virtual/emacs )
"
DEPEND="${RDEPEND}
	dev-python/setuptools[${PYTHON_USEDEP}]
	doc? ( dev-python/sphinx[${PYTHON_USEDEP}] )
	test? (
		$(python_gen_cond_dep 'dev-python/numpy[${PYTHON_USEDEP}]' \
			'python*')
	)"

SITEFILE=50cython-gentoo.el

python_compile() {
	if ! python_is_python3; then
		local CFLAGS="${CFLAGS} -fno-strict-aliasing"
		local CXXFLAGS="${CXXFLAGS} -fno-strict-aliasing"
	fi

	# Python gets confused when it is in sys.path before build.
	local -x PYTHONPATH=

	distutils-r1_python_compile
}

python_compile_all() {
	use emacs && elisp-compile Tools/cython-mode.el

	use doc && emake -C docs html
}

python_test() {
	tc-export CC
	# https://github.com/cython/cython/issues/1911
	local -x CFLAGS="${CFLAGS} -fno-strict-overflow"
	"${PYTHON}" runtests.py -vv --work-dir "${BUILD_DIR}"/tests \
		|| die "Tests fail with ${EPYTHON}"
}

python_install_all() {
	local DOCS=( CHANGES.rst README.rst ToDo.txt USAGE.txt )
	use doc && local HTML_DOCS=( docs/build/html/. )
	distutils-r1_python_install_all

	if use emacs; then
		elisp-install ${PN} Tools/cython-mode.*
		elisp-site-file-install "${FILESDIR}/${SITEFILE}"
	fi
}

pkg_postinst() {
	use emacs && elisp-site-regen
}

pkg_postrm() {
	use emacs && elisp-site-regen
}
