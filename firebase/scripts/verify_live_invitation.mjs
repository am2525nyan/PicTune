// Explicit opt-in integration check. Uses only temporary accounts and newly created fixtures.
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, createUserWithEmailAndPassword, deleteUser} from 'firebase/auth';
import {getFirestore, doc, setDoc, getDocFromServer, updateDoc, deleteDoc, writeBatch, arrayUnion, serverTimestamp, Timestamp, onSnapshot, terminate} from 'firebase/firestore';
import {getStorage, ref, uploadBytes, getMetadata, deleteObject} from 'firebase/storage';
import {readFileSync, writeFileSync, existsSync} from 'node:fs';
import {randomUUID, randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
if(process.env.PICTUNE_LIVE_INVITE_TEST !== '1') throw new Error('Set PICTUNE_LIVE_INVITE_TEST=1 to opt in');
const config=JSON.parse(readFileSync('/tmp/pictune-invite-firebase-config.json','utf8'));
const apps=[], accounts=[], documents=[], objects=[];
const id=randomUUID(), token=randomBytes(32).toString('hex'), file=`invite-check-${id}.jpg`;
const registerDoc=(db,path)=>{documents.push({db,path});return doc(db,path)};
async function denied(p){await assert.rejects(p,e=>e.code==='permission-denied'||e.code==='storage/unauthorized')}
try{
 for(const label of ['sender','recipient','outsider']){
  const app=initializeApp(config,`${label}-${id}`);apps.push(app);
  const credential=await createUserWithEmailAndPassword(getAuth(app),`pictune-${label}-${id}@example.invalid`,randomBytes(24).toString('hex'));
  accounts.push(credential.user);
 }
 const [a,b,c]=apps.map(app=>getFirestore(app)),[owner,recipient]=accounts.map(u=>u.uid);
 const folder=`users/${owner}/folders/invite-check-${id}`;
 const source=registerDoc(a,folder), photo=registerDoc(a,folder+'/photos/photo');
 await setDoc(source,{title:'招待の接続確認',letter:'before'});
 await setDoc(doc(a,'imageOwners/'+file),{ownerID:owner});
 const cleanupPath='/tmp/pictune-invite-live-cleanup.json';
 const previous=existsSync(cleanupPath)?JSON.parse(readFileSync(cleanupPath,'utf8')).imageOwners:[];
 writeFileSync(cleanupPath,JSON.stringify({imageOwners:[...previous,file]}));
 const storageRef=ref(getStorage(apps[0]),'images/'+file);objects.push(storageRef);
 console.log("Checking authenticated image upload");
 await uploadBytes(storageRef,new Uint8Array([0xff,0xd8,0xff,0xd9]),{contentType:'image/jpeg',customMetadata:{ownerIDs:owner}});
 await setDoc(photo,{url:file,date:serverTimestamp(),trackName:'verification-song',artistName:'PicTune',id:'fixture-track'});
 const invitation=registerDoc(a,'folderInvites/'+token);
 await setDoc(invitation,{ownerID:owner,folderID:`invite-check-${id}`,title:'招待の接続確認',senderName:'確認用',createdAt:serverTimestamp(),expiresAt:Timestamp.fromMillis(Date.now()+600000),revoked:false});
 await denied(getDocFromServer(doc(b,folder)));
 await getDocFromServer(doc(b,'folderInvites/'+token));
 const saved=registerDoc(b,`users/${recipient}/sharedFolders/verification`);
 const batch=writeBatch(b);
 batch.update(doc(b,folder),{sharedWith:arrayUnion(recipient),inviteToken:token});
 batch.set(saved,{ownerID:owner,folderID:`invite-check-${id}`,title:'招待の接続確認',joinedAt:serverTimestamp()});
 await batch.commit();
 const changed=new Promise((resolve,reject)=>{
  let stop=()=>{};const timeout=setTimeout(()=>{stop();reject(new Error('Live synchronization timed out'))},15000);
  stop=onSnapshot(doc(b,folder),snapshot=>{if(snapshot.data()?.letter==='after'){clearTimeout(timeout);stop();resolve()}},error=>{clearTimeout(timeout);reject(error)});
 });
 await updateDoc(source,{letter:'after'});await changed;
 await denied(updateDoc(doc(b,folder),{letter:'forged'}));
 const access=registerDoc(b,`users/${recipient}/imageAccess/${file}`);
 await setDoc(access,{ownerID:owner,folderID:`invite-check-${id}`,photoID:'photo'});
 await getMetadata(ref(getStorage(apps[1]),'images/'+file));
 await denied(getMetadata(ref(getStorage(apps[2]),'images/'+file)));
 await updateDoc(invitation,{revoked:true});
 await denied(getDocFromServer(doc(c,'folderInvites/'+token)));
 await deleteDoc(source);
 await denied(getDocFromServer(doc(b,folder)));
 await denied(getMetadata(ref(getStorage(apps[1]),'images/'+file)));
 console.log('PASS: live invitation, membership, realtime letter sync, read-only access, private image access, revocation and source deletion');
}finally{
 const failures=[];
 for(const object of objects.reverse())try{await deleteObject(object)}catch(e){failures.push(e.code)}
 for(const {db,path} of documents.reverse())try{await deleteDoc(doc(db,path))}catch(e){failures.push(e.code)}
 for(const user of accounts)try{await deleteUser(user)}catch(e){failures.push(e.code)}
 for(const app of apps){await terminate(getFirestore(app));await deleteApp(app)}
 console.log('Cleanup:', failures.length===0?'temporary data/accounts removed':JSON.stringify(failures));
}
