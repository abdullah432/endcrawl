// Playwright CLI run-code function; run against a loaded app over localhost/HTTPS.
async (page) => {
  const capabilities = await page.evaluate(() => endcrawlExport.capabilities());
  console.log(capabilities);
  for (const [name, num, den, memory] of [['24fps',24,1,false],['fractional',30000,1001,true]]) {
    await page.evaluate(async ({name,num,den,memory}) => {
      if(memory) Object.defineProperty(navigator.storage,'getDirectory',{value:undefined,configurable:true});
      const id = 'qa-'+name+'.mp4';
      await endcrawlExport.videoStart(id,64,36,num,den,500000);
      for(let frame=0;frame<60;frame++) {
        const rgba = new Uint8Array(64*36*4);
        for(let p=0;p<rgba.length;p+=4) {rgba[p]=(frame*4)%256;rgba[p+1]=120;rgba[p+2]=160;rgba[p+3]=255;}
        await endcrawlExport.videoAppend(id,rgba,frame);
      }
      const size = await endcrawlExport.videoFinish(id);
      if(size<=0) throw new Error('Empty MP4');
      if(memory) delete navigator.storage.getDirectory;
    },{name,num,den,memory});
    const pending = page.waitForEvent('download');
    await page.evaluate((name)=>endcrawlExport.download('qa-'+name+'.mp4',name+'.mp4'),name);
    const download = await pending;
    await download.saveAs('output/playwright/'+name+'.mp4');
    await page.evaluate(name=>endcrawlExport.release('qa-'+name+'.mp4'),name);
  }
  console.log(await page.evaluate(async () => {
    const original = Object.getOwnPropertyDescriptor(globalThis, 'VideoEncoder');
    Object.defineProperty(globalThis,'VideoEncoder',{value:undefined,configurable:true});
    const fallback = JSON.parse(await endcrawlExport.capabilities());
    if (original) Object.defineProperty(globalThis, 'VideoEncoder', original); else delete globalThis.VideoEncoder;
    return {noWebCodecs: fallback.maxEdge};
  }));
}
