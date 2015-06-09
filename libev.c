/*
 * libev.c
 */

#include "libev.h"

/*
 * The following function is a dummy one; replace it for
 * your C function definitions.
 */

ScmObj test_libev(void)
{
    return SCM_MAKE_STR("libev is working");
}

/*
 * Module initialization function.
 */
extern void Scm_Init_libevlib(ScmModule*);

void Scm_Init_libev(void)
{
    ScmModule *mod;

    /* Register this DSO to Gauche */
    SCM_INIT_EXTENSION(libev);

    /* Create the module if it doesn't exist yet. */
    mod = SCM_MODULE(SCM_FIND_MODULE("control.libev", TRUE));

    /* Register stub-generated procedures */
    Scm_Init_libevlib(mod);
}
