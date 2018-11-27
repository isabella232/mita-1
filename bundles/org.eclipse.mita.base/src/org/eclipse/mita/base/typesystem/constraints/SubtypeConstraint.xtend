package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.FunctionType

/**
 * Corresponds to subtype relationship sub <: sup as defined in
 * Extending Hindley-Milner Type Inference with Coercive Structural Subtyping
 * by Traytel et al., see https://www21.in.tum.de/~nipkow/pubs/aplas11.pdf
 */
@Accessors
@EqualsHashCode
class SubtypeConstraint extends AbstractTypeConstraint {
	protected final AbstractType subType;
	protected final AbstractType superType;
	
	new(AbstractType sub, AbstractType top, ValidationIssue errorMessage) {
		super(errorMessage);
		
		subType = sub;
		superType = top;
		if(this.toString.startsWith("v2d(v2d_s(i32, i32)) ⩽ f_57")) {
			print("")
		}
	}
	
	override getErrorMessage() {
		return new ValidationIssue(_errorMessage, String.format(_errorMessage.message, subType, superType));
	}
	
	override toString() {
		subType + " ⩽ " + superType
	}
		
	override getActiveVars() {
		return subType.freeVars + superType.freeVars;
	}
	
	override getOrigins() {
		return #[subType, superType].map[ it.origin ];
	}
	
	override getTypes() {
		return #[subType, superType];
	}
	
	override isAtomic() {
		return  (subType.isAtomic && superType.isAtomic) //&& (subType instanceof TypeVariable || superType instanceof TypeVariable)
	}
	
	private def isAtomic(AbstractType t) {
		return t instanceof AbstractBaseType || t instanceof TypeVariable || (t instanceof TypeConstructorType && !(t instanceof FunctionType))
	}
	
	override toGraphviz() {
		return '''"«subType»" -> "«superType»"; «subType.toGraphviz» «superType.toGraphviz»'''
	}
		
	override map((AbstractType)=>AbstractType f) {
		val newL = subType.map(f);
		val newR = superType.map(f);
		if(subType !== newL || superType !== newR) {
			if(this.toString == "f_31.0 ⩽ f_24.0" || this.toString == "f_58.0 ⩽ f_24.0") {
				print("")
			}
			return new SubtypeConstraint(newL, newR, _errorMessage);
		}
		return this;
	}
	
	override getOperator() {
		return "⩽"
	}
	
}