import {before, after, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, collection, setDoc, getDoc, getDocs, updateDoc, deleteDoc, writeBatch, arrayUnion, serverTimestamp, Timestamp} from 'firebase/firestore';
import {ref, uploadBytes, getMetadata} from 'firebase/storage';
let env;
const token='a'.repeat(64), cameraToken='b'.repeat(64);
const folder='users/alice/folders/trip';
const at=(delta)=>Timestamp.fromMillis(Date.now()+delta);
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-pictune-invites',firestore:{host:'127.0.0.1',port:8187,rules:readFileSync(new URL('../firestore.rules',import.meta.url),'utf8')},storage:{host:'127.0.0.1',port:9297,rules:readFileSync(new URL('../storage.rules',import.meta.url),'utf8')}})});
after(async()=>{await env?.cleanup()});
beforeEach(async()=>{
 await env.clearFirestore(); await env.clearStorage();
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  await setDoc(doc(db,folder),{title:'夏の記録',letter:'最初の手紙',sharedWith:[]});
  await setDoc(doc(db,'users/bob/folders/all'),{title:'all'});
  await setDoc(doc(db,folder+'/photos/p1'),{url:'photo.jpg',date:Timestamp.now(),trackName:'song',id:'track-id'});
  await setDoc(doc(db,'imageOwners/photo.jpg'),{ownerID:'alice'});
  await setDoc(doc(db,'folderInvites/'+token),{ownerID:'alice',folderID:'trip',title:'夏の記録',senderName:'Alice',createdAt:Timestamp.now(),expiresAt:at(600000),revoked:false});
  await uploadBytes(ref(c.storage(),'images/photo.jpg'),new Uint8Array([1,2,3]),{contentType:'image/jpeg',customMetadata:{ownerIDs:'alice'}});
 });
});
const db=(uid)=>uid?env.authenticatedContext(uid).firestore():env.unauthenticatedContext().firestore();
async function join(uid='bob'){
 const d=db(uid),batch=writeBatch(d);
 batch.update(doc(d,folder),{sharedWith:arrayUnion(uid),inviteToken:token});
 batch.set(doc(d,`users/${uid}/sharedFolders/stable`),{ownerID:'alice',folderID:'trip',title:'夏の記録',joinedAt:serverTimestamp()});
 return batch.commit();
}
test('anonymous access and invite enumeration are denied',async()=>{
 await assertFails(getDoc(doc(db(),folder)));await assertFails(getDoc(doc(db(),'folderInvites/'+token)));
 await assertFails(getDocs(collection(db('bob'),'folderInvites')));
 await assertFails(getDoc(doc(db('bob'),folder)));
 await assertFails(getMetadata(ref(env.unauthenticatedContext().storage(),'images/photo.jpg')));
});
test('known invitation joins atomically and repeat acceptance is idempotent',async()=>{
 await assertSucceeds(getDoc(doc(db('bob'),'folderInvites/'+token)));
 await assertSucceeds(join()); await assertSucceeds(join());
 assert.deepEqual((await getDoc(doc(db('alice'),folder))).data().sharedWith,['bob']);
 assert.equal((await getDocs(collection(db('bob'),'users/bob/sharedFolders'))).size,1);
});
test('forged token and membership do not grant access',async()=>{
 await assertFails(updateDoc(doc(db('eve'),folder),{sharedWith:['eve'],inviteToken:'f'.repeat(64)}));
 await assertFails(setDoc(doc(db('eve'),'users/eve/sharedFolders/forged'),{ownerID:'alice',folderID:'trip',title:'x',joinedAt:serverTimestamp()}));
 await assertFails(setDoc(doc(db('eve'),'users/eve/imageAccess/photo.jpg'),{ownerID:'alice',folderID:'trip',photoID:'p1'}));
});
test('recipient reads live changes but cannot edit sender data',async()=>{
 await join();
 await assertSucceeds(updateDoc(doc(db('alice'),folder),{letter:'更新した手紙'}));
 assert.equal((await getDoc(doc(db('bob'),folder))).data().letter,'更新した手紙');
 assert.equal((await getDoc(doc(db('bob'),folder+'/photos/p1'))).data().trackName,'song');
 await assertFails(updateDoc(doc(db('bob'),folder),{letter:'改ざん'}));
 await assertFails(deleteDoc(doc(db('bob'),folder+'/photos/p1')));
 await assertFails(updateDoc(doc(db('bob'),folder+'/photos/p1'),{trackName:'改ざん'}));
});
test('revoked/expired/deleted invitations refuse new participants',async()=>{
 await join();await updateDoc(doc(db('alice'),'folderInvites/'+token),{revoked:true});
 await assertFails(join('eve'));await assertSucceeds(getDoc(doc(db('bob'),folder)));
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'folderInvites/'+token),{revoked:false,expiresAt:at(-1000)}));
 await assertFails(join('eve'));
 await deleteDoc(doc(db('alice'),folder));await assertFails(getDoc(doc(db('bob'),folder)));
});
test('storage verifies membership, and deletion removes shared storage access',async()=>{
 await join();const d=db('bob');const storage=env.authenticatedContext('bob').storage();
 await assertFails(getMetadata(ref(storage,'images/photo.jpg')));
 await assertSucceeds(setDoc(doc(d,'users/bob/imageAccess/photo.jpg'),{ownerID:'alice',folderID:'trip',photoID:'p1'}));
 await assertSucceeds(getMetadata(ref(storage,'images/photo.jpg')));
 await assertFails(getMetadata(ref(env.authenticatedContext('eve').storage(),'images/photo.jpg')));
 await deleteDoc(doc(db('alice'),folder));await assertFails(getMetadata(ref(storage,'images/photo.jpg')));
});
test('users cannot fabricate own photos and storage grants for someone else’s image',async()=>{
 const d=db('eve'), b=writeBatch(d);
 b.set(doc(d,'users/eve/folders/all'),{title:'all'});
 b.set(doc(d,'users/eve/folders/all/photos/stolen'),{url:'photo.jpg'});
 b.set(doc(d,'users/eve/imageAccess/photo.jpg'),{ownerID:'eve',folderID:'all',photoID:'stolen'});
 await assertFails(b.commit());
 await assertFails(uploadBytes(ref(env.authenticatedContext('eve').storage(),'images/photo.jpg'),new Uint8Array([9]),{customMetadata:{ownerIDs:'eve'}}));
});
test('QR requires a recent invitation and preserves photo/music ownership',async()=>{
 const a=db('alice'),b=db('bob');
 await assertFails(setDoc(doc(a,'users/bob/folders/all/photos/q'),{url:'photo.jpg'}));
 await setDoc(doc(b,'cameraInvites/'+cameraToken),{ownerID:'bob',name:'Bob',createdAt:serverTimestamp(),expiresAt:at(600000)});
 const expiresAt=(await getDoc(doc(a,'cameraInvites/'+cameraToken))).data().expiresAt;
 await setDoc(doc(a,'users/bob/photoSenders/alice'),{inviteToken:cameraToken,expiresAt});
 const batch=writeBatch(a);
 batch.set(doc(a,'users/bob/folders/all/photos/q'),{url:'photo.jpg',trackName:'song',id:'track-id'});
 batch.set(doc(a,'users/bob/imageAccess/photo.jpg'),{ownerID:'bob',folderID:'all',photoID:'q'});
 await assertSucceeds(batch.commit());
 await assertSucceeds(getMetadata(ref(env.authenticatedContext('bob').storage(),'images/photo.jpg')));
 await assertFails(getDoc(doc(a,'users/bob/personal/info')));
 await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'users/bob/photoSenders/alice'),{expiresAt:at(-1000)}));
 await assertFails(setDoc(doc(a,'users/bob/folders/all/photos/q2'),{url:'photo.jpg'}));
});
test('owners can upload registered images; unregistered uploads are refused',async()=>{
 const a=db('alice'),storage=env.authenticatedContext('alice').storage();
 await assertFails(uploadBytes(ref(storage,'images/new.jpg'),new Uint8Array([1]),{contentType:'image/jpeg',customMetadata:{ownerIDs:'alice'}}));
 await setDoc(doc(a,'imageOwners/new.jpg'),{ownerID:'alice'});
 await assertSucceeds(uploadBytes(ref(storage,'images/new.jpg'),new Uint8Array([1]),{contentType:'image/jpeg',customMetadata:{ownerIDs:'alice'}}));
});
