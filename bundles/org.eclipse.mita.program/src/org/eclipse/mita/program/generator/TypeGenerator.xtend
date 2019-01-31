/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.program.generator

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.FloatingType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.generator.internal.GeneratorRegistry
import org.eclipse.mita.base.types.GeneratedType

import static extension org.eclipse.mita.base.types.TypesUtil.getConstraintSystem

/**
 * Facade for generating types.
 */
class TypeGenerator implements IGenerator {

	@Inject(optional=true)
	protected IPlatformExceptionGenerator exceptionGenerator
	
	@Inject
	protected CodeFragmentProvider codeFragmentProvider
	
	@Inject
	protected GeneratorRegistry generatorRegistry
	
	@Inject
	protected extension GeneratorUtils

	
	public dispatch def CodeFragment code(EObject context, AtomicType type) {
		if(type.name == "string") {
			return codeFragmentProvider.create('''char*''');
		}
		return codeFragmentProvider.create('''«type.getStructType(context)»''');
	}
	public dispatch def CodeFragment code(EObject context, ProdType type) {
		// if we have multiple members, we have an actual struct, otherwise we are just an alias
		if(type.typeArguments.length == 1 && context.eResource.constraintSystem.getUserData(type, BaseConstraintFactory.ECLASS_KEY) == "AnonymousProductType") {
			return code(context, type.typeArguments.head);
		}
		else {
			return codeFragmentProvider.create('''«type.getStructType(context)»''');	
		}
	}
	public dispatch def CodeFragment code(EObject context, SumType sumType) {
		return codeFragmentProvider.create('''«sumType.getStructType(context)»''');
	}
	
	public dispatch def CodeFragment code(EObject context, FunctionType type) {
		return codeFragmentProvider.create('''«code(context, type.to)» (*«type.name»)(«code(context, type.from)»)''')
	}
	
	public dispatch def CodeFragment code(EObject context, TypeConstructorType type) {
		return codeFragmentProvider.create('''«type.name»''')
	}
	
// TODO exceptions are atomic types, should be subtype of atomic
//	public dispatch def CodeFragment code(ExceptionTypeDeclaration exception, AbstractType typeSpec) {
//		return exceptionGenerator.exceptionType;
//	}
	
// TODO types need a flag/generator
//	public dispatch def CodeFragment code(GeneratedType type) {
//		return generatorRegistry.getGenerator(type)?.generateTypeSpecifier(typeSpec, type);
//	}
	
	public dispatch def CodeFragment code(EObject context, IntegerType type) {
		var result = codeFragmentProvider.create('''«type.CName»''')
		return result;
	}
	
	public dispatch def CodeFragment code(EObject context, FloatingType type) {
		var result = codeFragmentProvider.create('''«type.CName»''')
		return result;
	} 	
}