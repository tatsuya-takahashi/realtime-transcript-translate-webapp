<template>
  <div id="app">
    <h2 class = "text-left pl-3 mb-3 mt-1">
      音声翻訳webシステム
    </h2>
    <router-view/>
  </div>
</template>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
}
h2 {
  background: linear-gradient(transparent 70%, #a7d6ff 30%);
}

</style>
