import Vue from 'vue'
import VueRouter, { RouteConfig } from 'vue-router'
import experiments from '../views/experiments.vue'
import dev from '../views/dev/dev.vue'

Vue.use(VueRouter)

const routes: Array<RouteConfig> = [
  {
    path: '/',
    name: 'experiments',
    component: experiments
  },
  {
    path: '/dev',
    name: 'dev',
    component: dev
  },
]

const router = new VueRouter({
  mode: 'history',
  base: process.env.BASE_URL,
  routes
})

export default router
