/*-*-C++-*------------------------------------------------------------------
 * gaol -- NOT Just Another Interval Library
 *--------------------------------------------------------------------------
 * This file is part of the gaol distribution. Gaol was primarily 
 * developed at the Swiss Federal Institute of Technology, Lausanne, 
 * Switzerland, and is now developed at the Laboratoire d'Informatique de 
 * Nantes-Atlantique, France.
 *
 * Copyright (c) 2001 Swiss Federal Institute of Technology, Switzerland
 * Copyright (c) 2002-2006 Laboratoire d'Informatique de 
 *                         Nantes-Atlantique, France
 *--------------------------------------------------------------------------
 * gaol is a software distributed WITHOUT ANY WARRANTY. Read the associated 
 * COPYING file for information.
 *--------------------------------------------------------------------------
 * CVS: $Id: gaol_assert.h,v 1.2 2007/09/12 12:41:57 goualard Exp $
 * Last modified: 
 * By: 
 *--------------------------------------------------------------------------*/

/*!
  \file   gaol_assert.h
  \brief  Assertions

  Introduces a mechanism of assertions even if it is not supported by the 
  compiler/library at hand.
  
  \author Frederic Goualard
  \date   2006-02-21
*/


#ifndef __gaol_assert_h__
#define __gaol_assert_h__

#include "gaol/gaol_config.h"

#if GAOL_DEBUGGING
# if HAVE_CASSERT
#   include <cassert>
#   undef NDEBUG
#   define GAOL_ASSERT(a) assert(a)
# else
#   include <cstdlib>
#   define GAOL_ASSERT(a) if (!(a)) abort()
# endif // HAVE_CASSERT
#else 
# define GAOL_ASSERT(a) 
#endif  // GAOL_DEBUGGING

#endif /* __gaol_assert_h__ */