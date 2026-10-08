@extends('layout')
@section('content')
@php($me = auth()->user())
<h1>Fitur</h1><p class="muted">{{ $me->name }} · divisi {{ config('goyana.admin_divisions.'.$me->adminDivision().'.label') }}. Hanya menu divisi ini yang tampil.</p>
<div class="tiles">
@foreach($menu as [$route, $label, $icon, $color, $area])
@if($me->adminCan($area))<a class="tile" href="{{ route($route) }}"><span class="ic t-{{ $color }}">@include('admin-icon', ['icon' => $icon, 'size' => 26])</span>{{ $label }}</a>@endif
@endforeach
</div>
@endsection
