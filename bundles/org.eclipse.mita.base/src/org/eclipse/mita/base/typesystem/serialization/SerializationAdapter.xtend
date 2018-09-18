package org.eclipse.mita.base.typesystem.serialization

import com.google.gson.GsonBuilder
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParseException
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import com.google.inject.Inject
import com.google.inject.Provider
import java.lang.reflect.Type
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.EReference
import org.eclipse.emf.ecore.EcoreFactory
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.FunctionTypeClassConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.constraints.TypeClassConstraint
import org.eclipse.mita.base.typesystem.infra.TypeClass
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.CoSumType
import org.eclipse.mita.base.typesystem.types.FloatingType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtext.naming.QualifiedName

import static extension org.eclipse.mita.base.util.BaseUtils.force

class SerializationAdapter {
	
	@Inject 
	protected Provider<ConstraintSystem> constraintSystemProvider; 
	
	protected (URI) => EObject objectResolver;
		
	def fromJSON(String json, (URI)=>EObject objectResolver) {
		this.objectResolver = objectResolver ?: [URI uri| this.toEObjectProxy(uri) ];
		return new GsonBuilder()
    		.registerTypeHierarchyAdapter(SerializedObject, new MitaJsonSerializer())
    		.create()
    		.fromJson(json, SerializedObject)
    		.fromValueObject() as ConstraintSystem;
	}
	protected dispatch def EReference fromValueObject(SerializedEReference obj) {
		val registry = EPackage.Registry.INSTANCE;
		val ePackage = registry.getEPackage(obj.ePackageName);
		val eClass = ePackage.getEClassifier(obj.eClassName) as EClass;
		val result = eClass.getEStructuralFeature(obj.eReferenceName);
		return result as EReference;
	}	
	
	protected dispatch def ConstraintSystem fromValueObject(SerializedConstraintSystem obj) {
		val result = constraintSystemProvider.get();
		obj.constraints.map[ it.fromValueObject() as AbstractTypeConstraint ].forEach[ result.addConstraint(it) ];
		result.typeClasses.putAll(obj
			.typeClasses
			.entrySet
			.map[ it.key.toQualifiedName -> it.value.fromValueObject() as TypeClass ]
			.toMap([ it.key ], [ it.value ])
		);
		return result;
	}
	
	protected dispatch def EqualityConstraint fromValueObject(SerializedEqualityConstraint obj) {
		return new EqualityConstraint(obj.left.fromValueObject() as AbstractType, obj.right.fromValueObject() as AbstractType, obj.source);
	}
	
	protected dispatch def ExplicitInstanceConstraint fromValueObject(SerializedExplicitInstanceConstraint obj) {
		return new ExplicitInstanceConstraint(obj.instance.fromValueObject() as AbstractType, obj.typeScheme.fromValueObject() as AbstractType)
	}
	
	protected dispatch def SubtypeConstraint fromValueObject(SerializedSubtypeConstraint obj) {
		return new SubtypeConstraint(obj.subType.fromValueObject() as AbstractType, obj.superType.fromValueObject() as AbstractType)
	}
	
	protected dispatch def TypeClassConstraint fromValueObject(SerializedFunctionTypeClassConstraint obj) {
		return new FunctionTypeClassConstraint(obj.type.fromValueObject() as AbstractType, obj.instanceOfQN.toQualifiedName, obj.functionCall.resolveEObject, null, obj.returnTypeTV.fromValueObject as TypeVariable, null);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedAtomicType obj) {
		return new AtomicType(obj.origin.resolveEObject(), obj.name);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedBaseKind obj) {
		return new BaseKind(obj.origin.resolveEObject(), obj.name, obj.kindOf.fromValueObject() as AbstractType);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedBottomType obj) {
		return new BottomType(obj.origin.resolveEObject(), obj.name, obj.message);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedFloatingType obj) {
		return new FloatingType(obj.origin.resolveEObject(), obj.widthInBytes);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedIntegerType obj) {
		return new IntegerType(obj.origin.resolveEObject(), obj.widthInBytes, obj.signedness);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedFunctionType obj) {
		return new FunctionType(
			obj.origin.resolveEObject(),
			obj.name,
			obj.typeArguments.fromSerializedTypes(),
			obj.superTypes.fromSerializedTypes(),
			obj.from.fromValueObject() as AbstractType,
			obj.to.fromValueObject() as AbstractType
		);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedProductType obj) {
		return new ProdType(obj.origin.resolveEObject(), obj.name, obj.typeArguments.fromSerializedTypes(), obj.superTypes.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedCoSumType obj) {
		return new CoSumType(obj.origin.resolveEObject(), obj.name, obj.typeArguments.fromSerializedTypes(), obj.superTypes.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedSumType obj) {
		return new SumType(obj.origin.resolveEObject(), obj.name, obj.typeArguments.fromSerializedTypes(), obj.superTypes.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeConstructorType obj) {
		return new TypeConstructorType(obj.origin.resolveEObject(), obj.name, obj.typeArguments.fromSerializedTypes(), obj.superTypes.fromSerializedTypes());
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeScheme obj) {
		return new TypeScheme(obj.origin.resolveEObject(), obj.vars.map[ it.fromValueObject() as TypeVariable ].toList(), obj.on.fromValueObject() as AbstractType);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeVariable obj) {
		return new TypeVariable(obj.origin.resolveEObject(), obj.name);
	}
	
	protected dispatch def AbstractType fromValueObject(SerializedTypeVariableProxy obj) {
		// we resolve the origin of TypeVarProxies because we pass them to the scope later
		return new TypeVariableProxy(obj.origin.resolveEObject(true), obj.name, obj.reference.fromValueObject as EReference, obj.targetQID.toQualifiedName);
	}
	
	protected def Iterable<AbstractType> fromSerializedTypes(Iterable<SerializedAbstractType> obj) {
		return obj.map[ it.fromValueObject() as AbstractType ].toList();
	}
	
	protected def resolveEObject(String uri) {
		return resolveEObject(uri, false);
	}
	
	protected def resolveEObject(String uri, boolean resolveExternally) {
		return if(uri !== null) {
			val realUri = URI.createURI(uri);
			if(resolveExternally) {
				this.objectResolver.apply(realUri);
			} else {
				this.toEObjectProxy(realUri);
			}
		}
	}
	
	protected def toEObjectProxy(URI uri) {
		return EcoreFactory.eINSTANCE.createEObject() => [ (it as BasicEObjectImpl).eSetProxyURI(uri) ];
	}
	
	protected def toQualifiedName(String fqn) {
		return QualifiedName.create(fqn.split('\\.'))
	}
	
	def toJSON(ConstraintSystem system) {
		val gson = new GsonBuilder()
    		.create();
		return gson.toJson(system.toValueObject());
	}
	
	
	protected dispatch def SerializedObject toValueObject(EReference reference) {
		return new SerializedEReference => [
			ePackageName = (reference.eContainer as EClass).EPackage.nsURI;
			eClassName = (reference.eContainer as EClass).name;
			eReferenceName = reference.name;
		]
	}
	
	protected dispatch def SerializedObject toValueObject(ConstraintSystem obj) {
		new SerializedConstraintSystem => [
			constraints = obj.constraints.map[ it.toValueObject() as SerializedAbstractTypeConstraint ]
			typeClasses = obj.typeClasses
				.entrySet
				.map[ it.key.toString() -> it.value.toValueObject as SerializedTypeClass ]
				.toMap([ it.key ], [ it.value ]);
		]
	}
	
	protected dispatch def SerializedObject toValueObject(EqualityConstraint obj) {
		new SerializedEqualityConstraint => [
			source = obj.source
			left = obj.left.toValueObject as SerializedAbstractType
			right = obj.right.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(ExplicitInstanceConstraint obj) {
		new SerializedExplicitInstanceConstraint => [
			instance = obj.instance.toValueObject as SerializedAbstractType
			typeScheme = obj.typeScheme.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(SubtypeConstraint obj) {
		new SerializedSubtypeConstraint => [
			subType = obj.subType.toValueObject as SerializedAbstractType
			superType = obj.superType.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(FunctionTypeClassConstraint obj) {
		new SerializedFunctionTypeClassConstraint => [
			type = obj.typ.toValueObject as SerializedAbstractType
			functionCall = if(obj.functionCall === null) null else EcoreUtil.getURI(obj.functionCall).toString();
			functionReference = obj.functionReference.toValueObject;
			returnTypeTV = obj.returnTypeTV.toValueObject as SerializedTypeVariable;
			instanceOfQN = obj.instanceOfQN.toString()
		]
	}
	
//	protected dispatch def SerializedObject toValueObject(TypeConstructorType obj) {
//		new SerializedTypeConstructorType => [
//			name = obj.name;
//			origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString();
//			typeArguments = obj.typeArguments.map[it.toValueObject as SerializedAbstractType].force;
//			// TODO: get these translated: superTypes = 
//		]
//	}
	
	protected dispatch def SerializedObject toValueObject(TypeClass obj) {
		new SerializedTypeClass => [
			instances = obj.instances.entrySet
				.map[ it.key.toValueObject as SerializedAbstractType -> it.value.toValueObject ]
				.toMap([ it.key ], [ it.value ])
		]
	}
		
	protected dispatch def Object fill(SerializedAbstractBaseType ctxt, AbstractBaseType obj) {
		ctxt.name = obj.name;
		ctxt.origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString()
		return ctxt;
	}
	
	protected dispatch def Object fill(SerializedTypeVariable ctxt, TypeVariable obj) {
		ctxt.name = obj.name;
		ctxt.origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString()
		return ctxt;
	}
		
	protected dispatch def SerializedObject toValueObject(BaseKind obj) {
		new SerializedBaseKind => [
			fill(it, obj)
			kindOf = obj.kindOf.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(BottomType obj) {
		new SerializedBottomType => [
			fill(it, obj)
			message = message
		]
	}
	protected dispatch def SerializedObject toValueObject(AtomicType obj) {
		new SerializedAtomicType => [
			fill(it, obj)
		]
	}
	
	protected dispatch def SerializedObject toValueObject(FloatingType obj) {
		new SerializedFloatingType => [
			fill(it, obj)
			widthInBytes = obj.widthInBytes
		]
	}
	
	protected dispatch def SerializedObject toValueObject(IntegerType obj) {
		new SerializedIntegerType => [
			fill(it, obj)
			widthInBytes = obj.widthInBytes
			signedness = obj.signedness
		]
	}
	
	protected dispatch def Object fill(SerializedTypeConstructorType ctxt, TypeConstructorType obj) {
		ctxt.name = obj.name
		ctxt.origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString()
		ctxt.typeArguments = obj.typeArguments.map[ it.toValueObject as SerializedAbstractType ].toList
		ctxt.superTypes = obj.superTypes.map[ it.toValueObject as SerializedAbstractType ].toList
		return ctxt
	}
	
	protected dispatch def Object fill(SerializedTypeScheme ctxt, TypeScheme obj) {
		ctxt.name = obj.name;
		ctxt.vars = obj.vars.map[ it.toValueObject as SerializedTypeVariable ].force;
		ctxt.on = obj.on.toValueObject as SerializedAbstractType;
		ctxt.origin = if(obj.origin === null) null else EcoreUtil.getURI(obj.origin).toString()
		return ctxt;
	}
	
	protected dispatch def SerializedObject toValueObject(FunctionType obj) {
		new SerializedFunctionType => [
			fill(it, obj)
			from = obj.from.toValueObject as SerializedAbstractType
			to = obj.to.toValueObject as SerializedAbstractType
		]
	}
	
	protected dispatch def SerializedObject toValueObject(ProdType obj) {
		new SerializedProductType => [ fill(it, obj) ]
	}
	
	protected dispatch def SerializedObject toValueObject(CoSumType obj) {
		new SerializedCoSumType => [ fill(it, obj) ]
	}
	
	protected dispatch def SerializedObject toValueObject(SumType obj) {
		new SerializedSumType => [ fill(it, obj) ]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeConstructorType obj) {
		new SerializedTypeConstructorType => [
			fill(it, obj)
		]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeScheme obj) {
		new SerializedTypeScheme => [
			fill(it, obj)
			on = obj.on.toValueObject as SerializedAbstractType
			vars = obj.vars.map[ it.toValueObject as SerializedTypeVariable ].toList
		]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeVariable obj) {
		new SerializedTypeVariable => [
			fill(it, obj)
		]
	}
	
	protected dispatch def SerializedObject toValueObject(TypeVariableProxy obj) {
		new SerializedTypeVariableProxy => [
			fill(it, obj)
			it.reference = obj.reference?.toValueObject as SerializedEReference;
			it.targetQID = obj.targetQID.toString;
		]
	}
	

	protected static class MitaJsonSerializer implements JsonSerializer<SerializedObject>, JsonDeserializer<SerializedObject> {
				
		override serialize(SerializedObject src, Type typeOfSrc, JsonSerializationContext context) {
			val result = context.serialize(src);
			if(result instanceof JsonObject) {
				result.addProperty("__type", src.class.name);
			}
			return result;
		}
		
		override deserialize(JsonElement json, Type typeOfT, JsonDeserializationContext context) throws JsonParseException {
			val jsonObject = json.getAsJsonObject();
        	val type = jsonObject.get("_type").asString;
        	
			var clasz = Class.forName(/*this.class.package.name + */'org.eclipse.mita.base.typesystem.serialization.' + type);
			val result = clasz.getConstructor().newInstance();
			while(clasz !== null) {
		        for (field : clasz.getFields()) {
		            if(jsonObject.has(field.getName())) {
		            	val rawFieldValue = jsonObject.get(field.getName());
		            	val fieldValue = context.deserialize(rawFieldValue, field.getGenericType());
		                field.set(result, fieldValue);
		            }
		        }
				clasz = clasz.superclass;				
			}
			return result as SerializedObject;
		}
		
	}
	
}