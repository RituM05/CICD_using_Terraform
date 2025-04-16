const express = require("express");
const app = express();

app.get("/", (req,res)=>{
    res.send("Hello, from Ritu, pipeline is running successfully..");
});

app.listen(8080, ()=>{
    console.log ('Service is up');
});