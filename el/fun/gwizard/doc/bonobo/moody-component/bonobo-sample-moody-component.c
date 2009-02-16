/*
 * bonobo-sample-moody-component.c
 * generated by gwizard 0.0.0 on Fri Nov 16 14:56:01 2001
 */

/*
** Copyright (C) 2001 Dirk-Jan C. Binnema <djcb@djcbsoftware.nl>
**
** This program is free software; you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation; either version 2 of the License, or
** (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
**
*/

#include <bonobo/bonobo-generic-factory.h>

#include "good-mood.h"
#include "bad-mood.h"


static BonoboObject*
bonobo_sample_moody_component_factory (BonoboGenericFactory* factory, void* data)
{
	GoodMood *good_mood = good_mood_new ();
	BadMood  *bad_mood  = bad_mood_new ();
	
	bonobo_object_add_interface
		(BONOBO_OBJECT(good_mood), BONOBO_OBJECT(bad_mood));
       
	return BONOBO_OBJECT (good_mood);
}

                                           
               
BONOBO_OAF_FACTORY(
	"OAFIID:Bonobo_Sample_MoodyComponent_Factory",
	"bonobo-sample-moody-component", "0.0.0",
	bonobo_sample_moody_component_factory,
	NULL)